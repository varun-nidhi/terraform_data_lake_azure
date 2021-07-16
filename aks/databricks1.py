from airflow import DAG
from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'airflow',
    'email': ['airflow@example.com'],
    'depends_on_past': False,
}

with DAG(
        dag_id='example_databricks_operator_1',
        default_args=default_args,
        schedule_interval='@daily',
        start_date=days_ago(2),
        tags=['example'],
) as dag:
    new_cluster = {
        "num_workers": 1,
        "spark_version": "8.3.x-scala2.12",
        "spark_conf": {"spark.sql.sources.default": "parquet", "spark.sql.legacy.createHiveTableByDefault": "true"},
        "azure_attributes": {
            "first_on_demand": 1,
            "availability": "ON_DEMAND_AZURE",
            "spot_bid_max_price": -1
        },
        "node_type_id": "Standard_DS3_v2"
    }

    spark_new_cluster = DatabricksSubmitRunOperator(task_id='spark_new_cluster', new_cluster=new_cluster,
                                                    spark_jar_task={'main_class_name': 'wtf.Job2'},
                                                    libraries=[
                                                        {'jar': 'dbfs:/mnt/data/core/lib/scala_seed-1.0-SNAPSHOT.jar'}])

    spark_jar_task_all_use_cluster = DatabricksSubmitRunOperator(
        task_id='spark_jar_task_all_use_cluster',
        existing_cluster_id="0716-061358-bid810",
        spark_jar_task={'main_class_name': 'wtf.Job2'},
        libraries=[{'jar': 'dbfs:/mnt/data/core/lib/scala_seed-1.0-SNAPSHOT.jar'}],
    )

    spark_new_cluster >> spark_jar_task_all_use_cluster
