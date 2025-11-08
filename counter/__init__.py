import azure.functions as func
from azure.data.tables import TableClient
from azure.core.exceptions import ResourceNotFoundError
import os
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.function_name(name="counter")
@app.route(route="counter")  # URL path = /api/counter
def main(req: func.HttpRequest) -> func.HttpResponse:
    endpoint = os.environ.get("COSMOS_TABLE_ENDPOINT")
    key = os.environ.get("COSMOS_TABLE_KEY")
    table_name = os.environ.get("TABLE_NAME", "counter")

    partition_key = "counter"
    row_key = "visitors"

    client = TableClient(endpoint=endpoint, table_name=table_name, credential=key)

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
