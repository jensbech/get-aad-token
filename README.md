Get a bearer tokens from Azure Entra ID and copy it to some local location.

**Requirements**
- Azure CLI
- jq
- Linux or MacOS

**How to use?**
- Make `.env` file in root folder:
```
FEED_PATH="where-you-want-to-copy-the-token"
COMMON_SCOPE="dev-and-test-scope"
PROD_SCOPE="prod-scope"
```
- Run `bruno.sh` script and select environment.
