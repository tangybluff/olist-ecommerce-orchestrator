# dbt Transformations

This dbt project models Olist e-commerce data from raw BigQuery tables into analytics marts.

## Setup

1. Copy `profiles.yml.example` to `profiles.yml`.
2. Ensure environment variables are loaded.
3. Run:

```bash
dbt deps --profiles-dir .
dbt build --profiles-dir .
```

## Layers

- `staging`: type cleanup and column standardization
- `intermediate`: business joins and enriched entities
- `marts`: analytics-ready tables for reporting and downstream consumption
