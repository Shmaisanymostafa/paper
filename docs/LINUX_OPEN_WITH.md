# Linux PDF opening

The unique GTK GApplication receives command lines from both cold and existing-process launches through session D-Bus. File arguments are resolved against the initiating process working directory, capped at32 per request, filtered to local PDF paths, then imported by the existing bounded Flutter repository path. No remote fetch. No deletion of original files.

The desktop-entry template is under linux/packaging. A future installer must install its executable/icon and desktop file to standard application locations. No xdg-mime default command is run. The user selects Open With or default reader through their desktop environment.

Native Linux compilation and D-Bus cold/warm tests are not yet performed. Required tests: spaces/non-ASCII/relative paths, multiple documents, already-running app, missing/unreadable/oversized files, missing session bus, startup failure. Source-only until these pass.
