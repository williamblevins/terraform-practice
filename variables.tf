
variable "queue_mapping" {
  default = {
    "github" : [
      "pull_request_created",
      "pull_request_merged",
      "pull_request_closed",
      "issue_created",
      "issue_closed",
    ],
    "buildkite" : [
      "build_scheduled",
      "build_started",
      "build_finished",
      "job_scheduled",
      "job_started",
      "job_completed",
    ]
  }
}
