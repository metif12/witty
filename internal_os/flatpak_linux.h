#ifndef WITTY_INTERNAL_OS_FLATPAK_LINUX_H
#define WITTY_INTERNAL_OS_FLATPAK_LINUX_H

#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

typedef enum WittyFlatpakHostCommandState {
    WITTY_FLATPAK_INIT,
    WITTY_FLATPAK_ERROR,
    WITTY_FLATPAK_STARTED,
    WITTY_FLATPAK_EXITED,
} WittyFlatpakHostCommandState;

typedef struct WittyFlatpakHostCommand {
    char **argv;
    char *cwd;
    char **envp;
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;

    pthread_mutex_t mutex;
    pthread_cond_t condition;
    pthread_t thread;
    int thread_created;
    WittyFlatpakHostCommandState state;
    uint32_t pid;
    uint8_t exit_status;
    guint subscription;
    GMainLoop *loop;
    char *error_message;
} WittyFlatpakHostCommand;

static inline void witty_flatpak_host_command_set_error(
    WittyFlatpakHostCommand *command,
    const char *message
) {
    pthread_mutex_lock(&command->mutex);
    g_free(command->error_message);
    command->error_message = g_strdup(message != NULL ? message : "unknown error");
    command->state = WITTY_FLATPAK_ERROR;
    pthread_cond_broadcast(&command->condition);
    pthread_mutex_unlock(&command->mutex);
}

static inline void witty_flatpak_host_command_on_exit(
    GDBusConnection *bus,
    const gchar *sender_name,
    const gchar *object_path,
    const gchar *interface_name,
    const gchar *signal_name,
    GVariant *parameters,
    gpointer user_data
) {
    (void)sender_name;
    (void)object_path;
    (void)interface_name;
    (void)signal_name;
    WittyFlatpakHostCommand *command = user_data;
    uint32_t pid = 0;
    uint32_t raw_status = 0;
    g_variant_get(parameters, "(uu)", &pid, &raw_status);

    pthread_mutex_lock(&command->mutex);
    if (command->state != WITTY_FLATPAK_STARTED || command->pid != pid) {
        pthread_mutex_unlock(&command->mutex);
        return;
    }
    command->exit_status = (uint8_t)WEXITSTATUS(raw_status);
    command->state = WITTY_FLATPAK_EXITED;
    GMainLoop *loop = command->loop;
    guint subscription = command->subscription;
    pthread_cond_broadcast(&command->condition);
    pthread_mutex_unlock(&command->mutex);

    g_dbus_connection_signal_unsubscribe(bus, subscription);
    g_main_loop_quit(loop);
}

static inline int witty_flatpak_host_command_start(
    WittyFlatpakHostCommand *command,
    GDBusConnection *bus,
    GMainLoop *loop,
    GError **error
) {
    GUnixFDList *fd_list = g_unix_fd_list_new();
    if (g_unix_fd_list_append(fd_list, command->stdin_fd, error) < 0 ||
        g_unix_fd_list_append(fd_list, command->stdout_fd, error) < 0 ||
        g_unix_fd_list_append(fd_list, command->stderr_fd, error) < 0) {
        g_object_unref(fd_list);
        return -1;
    }

    GVariantBuilder fd_builder;
    g_variant_builder_init(&fd_builder, G_VARIANT_TYPE("a{uh}"));
    g_variant_builder_add(&fd_builder, "{uh}", 0, command->stdin_fd);
    g_variant_builder_add(&fd_builder, "{uh}", 1, command->stdout_fd);
    g_variant_builder_add(&fd_builder, "{uh}", 2, command->stderr_fd);

    GVariantBuilder env_builder;
    g_variant_builder_init(&env_builder, G_VARIANT_TYPE("a{ss}"));
    if (command->envp != NULL) {
        for (char **entry = command->envp; *entry != NULL; ++entry) {
            const char *separator = strchr(*entry, '=');
            if (separator == NULL) continue;
            char *key = g_strndup(*entry, (gsize)(separator - *entry));
            g_variant_builder_add(&env_builder, "{ss}", key, separator + 1);
            g_free(key);
        }
    }

    char *current_dir = command->cwd == NULL ? g_get_current_dir() : NULL;
    const char *cwd = command->cwd != NULL ? command->cwd : current_dir;
    GVariant *parameters = g_variant_new(
        "(^ay^aay@a{uh}@a{ss}u)",
        cwd,
        command->argv,
        g_variant_builder_end(&fd_builder),
        g_variant_builder_end(&env_builder),
        0
    );
    g_variant_ref_sink(parameters);
    g_free(current_dir);

    guint subscription = g_dbus_connection_signal_subscribe(
        bus,
        "org.freedesktop.Flatpak",
        "org.freedesktop.Flatpak.Development",
        "HostCommandExited",
        "/org/freedesktop/Flatpak/Development",
        NULL,
        G_DBUS_SIGNAL_FLAGS_NONE,
        witty_flatpak_host_command_on_exit,
        command,
        NULL
    );

    GVariant *reply = g_dbus_connection_call_with_unix_fd_list_sync(
        bus,
        "org.freedesktop.Flatpak",
        "/org/freedesktop/Flatpak/Development",
        "org.freedesktop.Flatpak.Development",
        "HostCommand",
        parameters,
        G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE,
        G_MAXINT,
        fd_list,
        NULL,
        NULL,
        error
    );
    g_variant_unref(parameters);
    g_object_unref(fd_list);
    if (reply == NULL) {
        g_dbus_connection_signal_unsubscribe(bus, subscription);
        return -1;
    }

    uint32_t pid = 0;
    g_variant_get(reply, "(u)", &pid);
    g_variant_unref(reply);

    pthread_mutex_lock(&command->mutex);
    command->pid = pid;
    command->subscription = subscription;
    command->loop = loop;
    command->state = WITTY_FLATPAK_STARTED;
    pthread_cond_broadcast(&command->condition);
    pthread_mutex_unlock(&command->mutex);
    return 0;
}

static inline void *witty_flatpak_host_command_thread(void *userdata) {
    WittyFlatpakHostCommand *command = userdata;
    GMainContext *context = g_main_context_new();
    g_main_context_push_thread_default(context);
    GMainLoop *loop = g_main_loop_new(context, TRUE);

    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (bus == NULL) {
        witty_flatpak_host_command_set_error(command, error != NULL ? error->message : NULL);
    } else if (witty_flatpak_host_command_start(command, bus, loop, &error) != 0) {
        witty_flatpak_host_command_set_error(command, error != NULL ? error->message : NULL);
    } else {
        g_main_loop_run(loop);
    }

    if (error != NULL) g_error_free(error);
    if (bus != NULL) g_object_unref(bus);
    g_main_loop_unref(loop);
    g_main_context_pop_thread_default(context);
    g_main_context_unref(context);
    return NULL;
}

static inline WittyFlatpakHostCommand *witty_flatpak_host_command_new(
    const char *const *argv,
    const char *cwd,
    const char *const *envp,
    int stdin_fd,
    int stdout_fd,
    int stderr_fd
) {
    WittyFlatpakHostCommand *command = g_new0(WittyFlatpakHostCommand, 1);
    if (command == NULL) return NULL;
    command->argv = g_strdupv((char **)argv);
    command->cwd = g_strdup(cwd);
    command->envp = envp != NULL ? g_strdupv((char **)envp) : NULL;
    command->stdin_fd = stdin_fd;
    command->stdout_fd = stdout_fd;
    command->stderr_fd = stderr_fd;
    command->state = WITTY_FLATPAK_INIT;
    pthread_mutex_init(&command->mutex, NULL);
    pthread_cond_init(&command->condition, NULL);
    return command;
}

static inline int witty_flatpak_host_command_spawn(
    WittyFlatpakHostCommand *command,
    uint32_t *pid
) {
    pthread_mutex_lock(&command->mutex);
    if (command->state != WITTY_FLATPAK_INIT) {
        pthread_mutex_unlock(&command->mutex);
        return -1;
    }
    if (pthread_create(&command->thread, NULL, witty_flatpak_host_command_thread, command) != 0) {
        command->error_message = g_strdup("unable to start Flatpak host-command thread");
        command->state = WITTY_FLATPAK_ERROR;
        pthread_mutex_unlock(&command->mutex);
        return -1;
    }
    command->thread_created = 1;
    while (command->state == WITTY_FLATPAK_INIT) {
        pthread_cond_wait(&command->condition, &command->mutex);
    }
    int result = command->state == WITTY_FLATPAK_STARTED ||
        command->state == WITTY_FLATPAK_EXITED ? 0 : -1;
    *pid = command->pid;
    pthread_mutex_unlock(&command->mutex);
    return result;
}

static inline int witty_flatpak_host_command_wait(
    WittyFlatpakHostCommand *command,
    uint8_t *status
) {
    pthread_mutex_lock(&command->mutex);
    if (command->state == WITTY_FLATPAK_INIT) {
        g_free(command->error_message);
        command->error_message = g_strdup("Flatpak host command must be started");
        pthread_mutex_unlock(&command->mutex);
        return -1;
    }
    while (command->state == WITTY_FLATPAK_STARTED) {
        pthread_cond_wait(&command->condition, &command->mutex);
    }
    if (command->state != WITTY_FLATPAK_EXITED) {
        pthread_mutex_unlock(&command->mutex);
        return -1;
    }
    *status = command->exit_status;
    pthread_mutex_unlock(&command->mutex);
    return 0;
}

static inline int witty_flatpak_host_command_signal(
    WittyFlatpakHostCommand *command,
    uint8_t signal_number,
    int process_group
) {
    pthread_mutex_lock(&command->mutex);
    if (command->state != WITTY_FLATPAK_STARTED) {
        pthread_mutex_unlock(&command->mutex);
        return 0;
    }
    uint32_t pid = command->pid;
    pthread_mutex_unlock(&command->mutex);

    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (bus == NULL) {
        pthread_mutex_lock(&command->mutex);
        g_free(command->error_message);
        command->error_message = g_strdup(error != NULL ? error->message : "unknown error");
        pthread_mutex_unlock(&command->mutex);
        if (error != NULL) g_error_free(error);
        return -1;
    }
    GVariant *reply = g_dbus_connection_call_sync(
        bus,
        "org.freedesktop.Flatpak",
        "/org/freedesktop/Flatpak/Development",
        "org.freedesktop.Flatpak.Development",
        "HostCommandSignal",
        g_variant_new("(uub)", pid, (uint32_t)signal_number, process_group),
        G_VARIANT_TYPE("()"),
        G_DBUS_CALL_FLAGS_NONE,
        G_MAXINT,
        NULL,
        &error
    );
    g_object_unref(bus);
    if (reply == NULL) {
        pthread_mutex_lock(&command->mutex);
        g_free(command->error_message);
        command->error_message = g_strdup(error != NULL ? error->message : "unknown error");
        pthread_mutex_unlock(&command->mutex);
        if (error != NULL) g_error_free(error);
        return -1;
    }
    g_variant_unref(reply);
    if (error != NULL) g_error_free(error);
    return 0;
}

static inline const char *witty_flatpak_host_command_error(
    WittyFlatpakHostCommand *command
) {
    return command->error_message;
}

static inline void witty_flatpak_host_command_free(
    WittyFlatpakHostCommand *command
) {
    if (command == NULL) return;
    if (command->thread_created) pthread_join(command->thread, NULL);
    pthread_cond_destroy(&command->condition);
    pthread_mutex_destroy(&command->mutex);
    g_strfreev(command->argv);
    g_free(command->cwd);
    g_strfreev(command->envp);
    g_free(command->error_message);
    g_free(command);
}

#endif
