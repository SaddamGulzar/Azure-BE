import azure.functions as func
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError
import os
import json
import logging

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.function_name(name="counter")
@app.route(route="counter")
def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        connection_string = os.environ.get("COSMOS_TABLE_CONNECTION_STRING")
        table_name = os.environ.get("TABLE_NAME", "counter")

        service = TableServiceClient.from_connection_string(conn_str=connection_string)
        client = service.get_table_client(table_name=table_name)

        partition_key = "counter"
        row_key = "visitors"

        try:
            entity = client.get_entity(partition_key=partition_key, row_key=row_key)
            count = int(entity.get("count", 0)) + 1
            entity["count"] = count
            client.update_entity(entity, mode="Replace")
        except ResourceNotFoundError:
            entity = {"PartitionKey": partition_key, "RowKey": row_key, "count": 1}
            client.create_entity(entity)
            count = 1

        return func.HttpResponse(
            body=json.dumps({"visitors": count}),
            mimetype="application/json",
            status_code=200
        )

    except Exception as e:
        logging.error(f"Error in counter function: {str(e)}")
        return func.HttpResponse(
            body=json.dumps({"error": str(e)}),
            mimetype="application/json",
            status_code=500
        )
