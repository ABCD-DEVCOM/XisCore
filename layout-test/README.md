# XisCore layout test: can one binary read databases made on another OS?

This folder has two read-only tests. They open the ABCD example databases
with `mx` and report which ones can be read. They never write to the ABCD
repository: each database is copied to a temporary folder first.

## What the tests answer

Question: does the official Linux `mx` read the Windows examples, and does
the Windows `mx.exe` read the Linux examples?

The examples are in the ABCD repository, under `www/bases-examples_Linux`
and `www/bases-examples_Windows`. Each database is a folder with
`data/<name>.mst`.

## Step 1 - Linux (official binaries)

```
bash linux/run_matrix_linux.sh  /path/to/ABCD/www  /path/to/mx  [/path/to/another/mx ...]
```

Use the official BIREME Linux `mx` (isis1660, 64-bit). Output:
`results/linux_matrix.txt`.

## Step 2 - Windows (the mx.exe you already use)

Open a Command Prompt in this folder and run:

```
windows\run_matrix_windows.bat  C:\path\to\ABCD\www  C:\path\to\mx.exe
```

Use the `mx.exe` from `cgi-bin\ansi` (isis1660, ANSI). Output:
`results\windows_matrix.txt` and one text file per database in
`results\out\`.

## Step 3 - send back

Zip the `results` folder and send it. Nothing else is needed.

## How to read the verdicts

- `OK`: records were printed (`mfn=` lines) and no fatal error.
- `FATAL`: the program stopped. The message is in the report, for example
  `recread/check/base`.
- `EMPTY`: no records and no message. Usually the database has no records,
  or the test does not apply to it.

## Limits of this test

- It checks only the example databases in the repository, not a full ABCD
  installation. Passing these does not show that all ABCD databases work.
- The test reads the whole database with the command `mx <db> "" ""`. It does
  not run ABCD scripts, so it cannot find problems in the `wxis` side
  (such as the login script).
- The Windows script was written for the batch interpreter of Windows and was
  not run on Windows before being delivered. If a line fails, send the message
  shown on screen.
