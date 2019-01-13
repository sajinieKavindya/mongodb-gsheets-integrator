import ballerina/config;
import ballerina/io;
import ballerina/http;
import ballerina/log;
import wso2/mongodb;
import wso2/gsheets4;
import wso2/gmail;


# MongoDB database name
string databaseName = config:getAsString("DATABASE_NAME");

# Sender email address.
string senderEmail = config:getAsString("SENDER");

# The user's email address.
string dbAdminEmail = config:getAsString("DB_ADMIN_EMAIL");


gsheets4:SpreadsheetConfiguration spreadsheetConfig = {
    clientConfig: {
        auth: {
            scheme: http:OAUTH2,
            accessToken: config:getAsString("GSHEETS_ACCESS_TOKEN"),
            clientId: config:getAsString("CLIENT_ID"),
            clientSecret: config:getAsString("CLIENT_SECRET"),
            refreshToken: config:getAsString("GSHEETS_REFRESH_TOKEN")
        }
    }
};

gmail:Client gmailClient = new({
        clientConfig: {
            auth: {
                scheme: http:OAUTH2,
                accessToken: config:getAsString("GMAIL_ACCESS_TOKEN"),
                clientId: config:getAsString("CLIENT_ID"),
                clientSecret: config:getAsString("CLIENT_SECRET"),
                refreshToken: config:getAsString("GMAIL_REFRESH_TOKEN")
            }
        }
    });

mongodb:Client conn = new({
        host: "localhost",
        dbName: "testballerina",
        username: "",
        password: "",
        options: { sslEnabled: false, serverSelectionTimeout: 500 }
    });

gsheets4:Client spreadsheetClient = new(spreadsheetConfig);

public function main() {

    log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection");
    boolean success = insertSpreadsheetDataIntoMongoDBCollection();
    if (success) {
        log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection successfully completed!");
    } else {
        log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection failed!");
    }

    log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet");
    success = getMongoDBDataIntoSpreadsheet();
    if (success) {
        log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet successfully completed!");
    } else {
        log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet failed!");
    }

    log:printDebug("Mongo-Spredsheet integration -> Updating collection data");
    success = updateSpreadsheetDataInMongoDB();
    if (success) {
        log:printDebug("Mongo-Spredsheet integration -> Updating collection data successfully completed!");
    } else {
        log:printDebug("Mongo-Spredsheet integration -> Updating collection data failed!");
    }

    conn.stop();

}

function insertSpreadsheetDataIntoMongoDBCollection() returns boolean {
    io:println("Inserting spreadsheet data to MongoDB collection");
    //retrieve details from spreadsheet.
    var details = getAllEmployeeDetailsFromGSheet();
    if (details is error) {
        log:printError("Failed to retrieve details from GSheet", err = details);
        return false;
    } else {
        string[] keys;
        int noOfColumns = 0;
        json docArray = [];

        //Iterate through each customer details and send customized email.
        int i = 0;
        foreach var value in details {
            if (i == 0){
                keys = value;
                noOfColumns = keys.length();
            }else {
                json doc = {};
                int j = 0;
                while (j < noOfColumns){
                    doc[keys[j]] = value[j];
                    j+=1;
                }
                docArray[i-1] = doc;
            }
            i+=1;
        }

        string collectionName = io:readln("Enter collection name: ");
        var ret = conn->batchInsert(collectionName, docArray);
        handleInsert(ret, "Insert to collection " + collectionName);

        //send Email to DB Admin.
        string subject = "Security Alert - MongoDB Database";
        sendMail(subject, getCustomEmailTemplate(collectionName, "INSERT"));
    }
    return true;
}


function updateSpreadsheetDataInMongoDB() returns boolean {
    //retrieve details from spreadsheet.
    var details = getAllEmployeeDetailsFromGSheet();

    if (details is error) {
        log:printError("Failed to retrieve details from GSheet", err = details);
        return false;
    } else {
        int i = 0;
        int noOfColumns = 0;
        string[] keys;
        string collectionName = io:readln("Enter collection name: ");
        json docArray = [];

        //Iterate through each sheetdata.
        foreach var value in details {
            if (i == 0){
                keys = value;
                noOfColumns = value.length();
            }else {
                json doc = {};
                int j = 0;
                while (j < noOfColumns){
                    doc[keys[j]] = value[j];
                    j+=1;
                }
                json filter = {"id": value[0]};
                json updateDoc = {};
                updateDoc["$set"] = doc;

                var ret = conn->update(collectionName, filter, updateDoc, false, true);
                handleUpdate(ret, "row(s) updated in collection " + collectionName);
            }
            i += 1;
        }

        //send Email to DB Admin.
        string subject = "Security Alert - MongoDB Database";
        sendMail(subject, getCustomEmailTemplate(collectionName, "UPDATE"));
    }
    return true;

}

function getMongoDBDataIntoSpreadsheet() returns boolean {
    string newSpreadsheetId = "";
    string newSheetName = "";
    boolean isSuccess = false;
    io:println("Getting collection data to spreadsheet");

    //getting user inputs
    int operation = 0;
    while (operation != 1 && operation != 2) {
        io:println("Select an option. ");
        io:println("1. Create a new google sheet.");
        io:println("2. Open an existing google sheet.");

        string val = io:readln("Enter choice 1 or 2: ");
        var choice = int.convert(val);
        if (choice is int) {
            operation = choice;
        } else if(choice is error) {
            io:println("Invalid choice \n");
            continue;
        }

        gsheets4:Spreadsheet spreadsheet = new;

        if (operation == 1) {
            string spreadsheetName = io:readln("Enter spreadsheet name: ");
            newSheetName = "sheet1";

            var response = spreadsheetClient->createSpreadsheet(spreadsheetName);
            if (response is gsheets4:Spreadsheet) {
                spreadsheet = response;
            }else {
                log:printError("Failed to create a Google spreadsheet", err = response);
                return false;
            }

        }else if (operation == 2) {
            newSpreadsheetId = io:readln("Enter spreadsheet id: ");
            newSheetName = io:readln("Enter sheet name: ");

            var response = spreadsheetClient->openSpreadsheetById(newSpreadsheetId);
            if (response is gsheets4:Spreadsheet) {
                spreadsheet = response;
            }else {
                log:printError("Failed to create a Google spreadsheet", err = response);
                return false;
            }

        }else {
            continue;
        }

        newSpreadsheetId = spreadsheet.spreadsheetId;
        string collectionName = io:readln("Enter collection name: ");
        var data = getDataFromMongoDB(collectionName);

        if(data is error) {
            log:printError("Failed to retrieve details from GSheet", err = data);
            return false;
        }else {
            isSuccess = setGSheetValues(untaint newSpreadsheetId, newSheetName, data);
        }

        //send Email to DB Admin.
        string subject = "Security Alert - MongoDB Database";
        sendMail(subject, getCustomEmailTemplate(collectionName, "READ"));
        break;
    }
    return isSuccess;
}


function setGSheetValues(@sensitive string spreadsheetId, string sheetName, string[][] data) returns boolean{

    var isSuccess = spreadsheetClient->setSheetValues(untaint spreadsheetId, sheetName, topLeftCell="", bottomRightCell="", data);
    if (isSuccess is error) {
        log:printError("Failed to set values in GSheet", err = isSuccess);
        return false;
    } else {
        boolean b = isSuccess;
        if (!b) {
            log:printDebug("Failed to set values in GSheet");
            return false;
        }
    }
    return true;
}

function getDataFromMongoDB(string collectionName) returns string[][]|error {
    //retrieve data from mongoDB
    string[][] data = [];

    var jsonRet = conn->find(collectionName, ());
    if (jsonRet is json) {
        int noOfJsonObjects = jsonRet.length();
        if (noOfJsonObjects > 0) {
            //removing key "_id"
            json item = jsonRet[0];
            item.remove("_id");
            string[] keySet = item.getKeys();
            int noOfKeys = keySet.length();

            int i = 0;
            string[] element = [];
            while (i < noOfKeys) {
                element[i] = keySet[i];
                i+=1;
            }
            data[0] = element;

            i = 0;
            while (i < noOfJsonObjects) {
                int j = 0;
                string[] elem = [];
                while (j < noOfKeys) {
                    json k = jsonRet[i];
                    elem[j] = k[keySet[j]].toString();
                    j+=1;
                }
                i+=1;
                data[i] = elem;
            }
        }
    } else {
        log:printError("find failed: ", err = jsonRet);
        return jsonRet;
    }
    return data;
}


function getAllEmployeeDetailsFromGSheet() returns string[][]|error {
    //Read all the values from the sheet.
    string spreadsheetId = io:readln("Enter spreadsheet ID: ");
    string sheetName = io:readln("Enter sheet name: ");
    string[][] values = check spreadsheetClient->getSheetValues(spreadsheetId, sheetName);

    log:printInfo("Retrieved customer details from spreadsheet id: " + spreadsheetId + "; sheet name: "
            + sheetName);
    return values;
}

function getSpecificEmployeeDetailsFromGSheet() returns string[][]|error {
    //Read specific values from the sheet.
    string spreadsheetId = io:readln("Enter spreadsheet ID: ");
    string sheetName = io:readln("Enter sheet name: ");
    string topCell = io:readln("Enter top left cell: ");
    string bottomCell = io:readln("Enter bottom right cell: ");

    string[][] values = check spreadsheetClient->getSheetValues(spreadsheetId, sheetName, topLeftCell=topCell, bottomRightCell=bottomCell);
    log:printInfo("Retrieved customer details from spreadsheet id: " + spreadsheetId + "; sheet name: "
            + sheetName);
    return values;
}

function handleInsert(()|error returned, string message) {
    if (returned is ()) {
        io:println(message + " success ");
    } else {
        io:println(message + " failed: " + returned.reason());
    }
}

function handleFind(json|error returned) {
    if (returned is json) {
        io:print("initial data:");
        io:println(io:sprintf("%s", returned));
    } else {
        io:println("find failed: " + returned.reason());
    }
}

function handleUpdate(int|error returned, string message){
    if (returned is int) {
        io:println(returned + message);
    } else {
        io:println("update failed: " + returned.reason());
    }
}

function getCustomEmailTemplate(string collectionName, string operation) returns string {
    string emailTemplate = "";
    emailTemplate = emailTemplate + "<p> Some modifications have been made to "+ databaseName +"database.</p>";
    emailTemplate = emailTemplate + "<p> Collection Name : "+ collectionName+" </p> ";
    emailTemplate = emailTemplate + "<p> Action : "+ operation+" </p> ";
    return emailTemplate;
}

function sendMail(string subject, string messageBody) {
    //Create html message
    gmail:MessageRequest messageRequest = {};
    messageRequest.recipient = dbAdminEmail;
    messageRequest.sender = senderEmail;
    messageRequest.subject = subject;
    messageRequest.messageBody = messageBody;
    messageRequest.contentType = gmail:TEXT_HTML;

    //Send mail
    io:println("sending mail");
    var sendMessageResponse = gmailClient->sendMessage(senderEmail, untaint messageRequest);
    io:println(sendMessageResponse);
    string messageId;
    string threadId;
    if (sendMessageResponse is (string, string)) {
        (messageId, threadId) = sendMessageResponse;
        log:printInfo("Sent email to " + dbAdminEmail + " with message Id: " + messageId +
                " and thread Id:" + threadId);
    } else {
        log:printInfo(<string>sendMessageResponse.detail().message);
    }
}



