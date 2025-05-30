# OneCommandServer
A Minecraft server in a single command
# Usage: <br>
Enter the following command in PowerShell:<br>
`iex "&{$(irm https://p.wbif.ru/paper)} -v 1.21.5"`
Supported arguments:
- [-v | -version <version>] - Specifies the version of the Paper Minecraft server
- [-p | -port <port>] - Specifies the port the server will run on
- [-op | -openPort] - if argument is set,the script will install the UPnP port opener by nikita51 (https://github.com/nikita51bot/UPnPPortOpen)

If the version is not specified, the server will be enabled with the latest version of Paper.
