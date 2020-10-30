# terraform-practice

### Tested with various events on the source queue:
```
{
  "source": "github",
  "type": "pull_request_merged",
  "reference_url": "https://github.com/EOSIO/my-test-repo",
  "date": "2018-10-04 18:01:58 UTC"
}
```

```
{
  "source": "buildkite",
  "type": "build_started",
  "reference_url": "https://github.com/EOSIO/my-test-repo",
  "date": "2018-10-04 18:01:58 UTC"
}
```

### Tested infrastructure dependencies
1. `terraform apply`
1. `terraform destroy`
1. `terraform apply`

### Extending supported types
1. Update `variables.tf` and run `terraform apply`.

### Additional requirements for real operations.
1. Testing
    1. Unit testing especially around exception handling: retryable vs non-retrable errors.
    1. Integration testing with a test queue endpoint.
1. Possibly optimize for non-1 batch size and SQS.sendMessageBatch.
1. Alarms and monitoring.
