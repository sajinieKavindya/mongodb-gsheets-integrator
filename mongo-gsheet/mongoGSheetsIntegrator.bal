import ballerina/config;
import ballerina/io;
import ballerina/http;
import ballerina/log;
import wso2/mongodb;
import wso2/gsheets4;

string databaseName = config:getAsString("DATABASE_NAME");

gsheets4:SpreadsheetConfiguration spreadsheetConfig = {
    clientConfig: {
        auth: {
            scheme: http:OAUTH2,
            accessToken: config:getAsString("ACCESS_TOKEN"),
            clientId: config:getAsString("CLIENT_ID"),
            clientSecret: config:getAsString("CLIENT_SECRET"),
            refreshToken: config:getAsString("REFRESH_TOKEN")
        }
    }
};

mongodb:Client conn = new({
    host: "localhost",
    dbName: "testballerina",
    username: "",
    password: "",
    options: { sslEnabled: false, serverSelectionTimeout: 500 }
});

gsheets4:Client spreadsheetClient = new(spreadsheetConfig);

public function main() {

    log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet");
    boolean success = getMongoDBDataIntoSpreadsheet();
    if (success) {
        log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet successfully completed!");
    } else {
        log:printDebug("Mongo-Spredsheet integration -> Getting collection data to spreadsheet failed!");
    }

    log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection");
    success = insertSpreadsheetDataIntoMongoDBCollection();
    if (success) {
        log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection successfully completed!");
    } else {
        log:printDebug("Mongo-Spredsheet integration -> Inserting spreadsheet data to MongoDB collection failed!");
    }

    conn.stop();

}

//update
function updateSpreadsheetDataInMongoDB() returns boolean {
    //retrieve details from spreadsheet.
    var details = getAllEmployeeDetailsFromGSheet();

    if (details is error) {
        log:printError("Failed to retrieve details from GSheet", err = details);
        return false;
    } else {
        int i = 0;
        string[] keys;
        int noOfColumns = 0;

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

                json updateDoc = {};
                updateDoc["$set"] = doc;

                json filter = {};

                var ret = conn->update("e", filter, updateDoc, false, true);
                io:println(ret);

            }
            i += 1;
        }
    }

    return true;

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

        newSpreadsheetId = untaint spreadsheet.spreadsheetId;
        isSuccess = setGSheetValues(newSpreadsheetId, newSheetName);
        break;
    }
    return isSuccess;
}

function setGSheetValues(@sensitive string spreadsheetId, string sheetName ) returns boolean{
    var data = getDataFromMongoDB();

    if(data is error) {
        log:printError("Failed to retrieve details from GSheet", err = data);
        return false;
    }else {
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
    }
    return true;
}

function getDataFromMongoDB() returns string[][]|error {
    //retrieve data from mongoDB
    string collectionName = io:readln("Enter collection name: ");
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



