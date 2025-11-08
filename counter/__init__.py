import azure.functions as func
from azure.data.tables import TableClient
from azure.core.exceptions import ResourceNotFoundError
import os
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.function_name(name="counter")
@app.route(route="counter")  # URL path = /api/counter
def main(req: func.HttpRequest) -> func.HttpResponse:
    # Use connection string from Terraform-managed environment variable
    connection_string = os.environ.get("COSMOS_TABLE_CONNECTION_STRING")
    table_name = os.environ.get("TABLE_NAME", "counter")

    partition_key = "counter"
    row_key = "visitors"

    # Connect to the table
    client = TableClient.from_connection_string(conn_str=connection_string, table_name=table_name)

    try:
        # Try to get the entity
        entity = client.get_entity(partition_key=partition_key, row_key=row_key)
        count = int(entity.get("count", 0)) + 1
        entity["count"] = count
        client.update_entity(entity, mode="Replace")
    except ResourceNotFoundError:
        # If entity does not exist, create it
        entity = {"PartitionKey": partition_key, "RowKey": row_key, "count": 1}
        client.create_entity(entity)
        count = 1

    return func.HttpResponse(
        body=json.dumps({"visitors": count}),
        mimetype="application/json",
        status_code=200
    )
