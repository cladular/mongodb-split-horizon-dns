# Terraforming a Serverless MongoDB Replica Set with Split Horizon DNS on Azure and Cloudflare
This repository contains the scripts disscused in the article [Terraforming a Serverless MongoDB Replica Set with Split Horizon DNS on Azure and Cloudflare](https://medium.com/microsoftazure/terraforming-a-serverless-mongodb-replica-set-with-split-horizon-dns-on-azure-and-cloudflare-9687e37dacf1).

## Configuration
The root `main.tf` file contains a few values that require being set prior to running the script:
- `cloudflare/email`: Email address of the Cloudflare account
- `cloudflare/api_key`: API key of the Cloudflare account
- `locals/zone_name`: The root domain that will be used for the internal and external DNS zones (like `example.com`), which must be available in the Cloudflare account configured previously.

This can be further improved by passing these values through the command line or environment variables.
