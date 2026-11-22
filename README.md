A translated fork of Ghostty

`Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors`


<img width="752" height="528" alt="image" src="https://github.com/user-attachments/assets/5962e635-1197-48f7-9926-e564ff4f4c84" />

## Building on Linux

Use the V revision and Linux dependencies specified in CI. [CI workflow](.github/workflows/ci.yml)

From the repository root, run the build driver.

```sh
VFLAGS='-cc clang' v -path "$PWD|@vlib|@vmodules" run tools/build install
```

Run the installed application with `./v-out/bin/ghostty`.
