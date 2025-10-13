# Making OpenTelemetry Transformation Language enjoyable

| Signal             | Path Prefix Values                             |
| ------------------ | ---------------------------------------------- |
| trace_statements   | `resource`, `scope`, `span`, and `spanevent`   |
| metric_statements  | `resource`, `scope`, `metric`, and `datapoint` |
| log_statements     | `resource`, `scope`, and `log`                 |
| profile_statements | `resource`, `scope`, and `profile`             |
## Supported functions:
These common functions can be used for any Signal.

- [OTTL Functions](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/pkg/ottl/ottlfuncs)

In addition to the common OTTL functions, the processor defines its own functions to help with transformations specific to this processor:

**Metrics only functions**

- [convert_sum_to_gauge](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_sum_to_gauge)
- [convert_gauge_to_sum](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_gauge_to_sum)
- [extract_count_metric](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#extract_count_metric)
- [extract_sum_metric](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#extract_sum_metric)
- [convert_summary_count_val_to_sum](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_summary_count_val_to_sum)
- [convert_summary_quantile_val_to_gauge](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_summary_quantile_val_to_gauge)
- [convert_summary_sum_val_to_sum](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_summary_sum_val_to_sum)
- [copy_metric](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#copy_metric)
- [scale_metric](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#scale_metric)
- [aggregate_on_attributes](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#aggregate_on_attributes)
- [convert_exponential_histogram_to_histogram](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#convert_exponential_histogram_to_histogram)
- [aggregate_on_attribute_value](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#aggregate_on_attribute_value)
- [merge_histogram_buckets](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor#merge_histogram_buckets)


## Solving the designing UI

- Taking user input and showing them like jupyternotebook. 