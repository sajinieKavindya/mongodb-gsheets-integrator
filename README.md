# mongodb-gsheets-integrator

This module brings you the whole new way of interacting with MongoDB collctions to Create, Read, Update documents directly through Google Spreadsheet. Complex JSON objects in documents are represented by rows and columns, giving more understandable and insightful to data stored in collections.

This application uses Ballerina Google spreadsheet connector and Ballerina MongoDB connector to perform Create, Read, Update on mongoDB collections and Ballerina GMail connector to send an email to the database admin about the modifications done on database. Following diagrams show the high level architecture of the application.  

#Prerequisites

- [Ballerina Distribution](https://ballerina.io/#install-ballerina)

- Ballerina IDE plugins ([IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina))

- Go through the following steps to obtain credetials and tokens for both Google Sheets and GMail APIs.

  1. Visit [Google API Console](https://console.developers.google.com/apis/dashboard?project=newgsheetsproject&duration=PT1H), click **Create Project**, and follow the wizard to create a new project.
  2. Enable both GMail and Google Sheets APIs for the project.
  3. Go to **Credentials -> OAuth consent screen**, enter a product name to be shown to users, and click **Save**.
  4. On the **Credentials** tab, click **Create credentials** and select **OAuth client ID**.
  5. Select an application type, enter a name for the application, and specify a redirect URI (enter https://developers.google.com/oauthplayground if you want to use [OAuth 2.0 playground](https://developers.google.com/oauthplayground/) to receive the authorization code and obtain the access token and refresh token).
  6. Click **Create**. Your client ID and client secret appear.
  7. In a separate browser window or tab, visit [OAuth 2.0 playground](https://developers.google.com/oauthplayground/), Click on the `OAuth 2.0 configuration` icon in the top right corner and click on `Use your own OAuth credentials` and provide your `OAuth Client ID` and `OAuth Client secret`.
  8. Select the required Google sheets scopes from the list of API's, and then click Authorize APIs.
  9. When you receive your authorization code, click Exchange authorization code for tokens to obtain the refresh token and access token.
  10. Repeat steps **viii** (select required Gmail scopes from the list) and **ix** to obtain tokens for Gmail.

You must configure the `ballerina.conf` configuration file with the above obtained tokens, credentials and other important parameters as follows.

```
GSHEETS_ACCESS_TOKEN="access token for Google sheets"
GSHEETS_REFRESH_TOKEN="refresh token for Google sheets"

GMAIL_ACCESS_TOKEN="access token for Gmail"
GMAIL_REFRESH_TOKEN="refresh token for Gmail"

CLIENT_ID="client id"
CLIENT_SECRET="client secret"

DATABASE_NAME="MongoDB database name"
SENDER="sender's email"
DB_ADMIN_EMAIL="email of the database admin"
```
