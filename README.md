# terraform-practice

###Tested with various events on the source queue:
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

### Extending supported types
1. Update `variables.tf` and run `terraform apply`.

### Additional requirements for real operations.
1. Unit tests.
2. Possibly optimize for non-1 batch size and SQS.sendMessageBatch.
3. Alarms and monitoring.