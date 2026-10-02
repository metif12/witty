#pragma once
#include <CoreServices/CoreServices.h>
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// ABI adapters; URL and editor selection remain in open_url_darwin.c.v.
static inline void* witty_open_url_plain_text_type(void) { return (void*)UTTypePlainText; }
static inline void* witty_open_url_default_application(void* identifier) {
    return (void*)LSCopyDefaultApplicationURLForContentType((CFStringRef)identifier, kLSRolesAll, NULL);
}
static inline void witty_open_urls_with_application(void* workspace, void* urls, void* application, void* configuration) {
    ((void (*)(id,SEL,id,id,id,id))objc_msgSend)((id)workspace,
        sel_registerName("openURLs:withApplicationAtURL:configuration:completionHandler:"),
        (id)urls,(id)application,(id)configuration,nil);
}
