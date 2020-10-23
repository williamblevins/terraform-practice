// nodejs12x runtime AWS Lambda function

const AWS = require('aws-sdk');
AWS.config.update({region: process.env.AWS_REGION});

const SQS = new AWS.SQS({apiVersion: '2012-11-05'});

// Event shape example.
// {
//     "source": "github",
//     "type": "pull_request",
//     "reference_url": "https://github.com/EOSIO/my-test-repo",
//     "date": "2018-10-04 18:01:58 UTC"
// }

exports.handler = (event, context, callback) => {
    const region = process.env.AWS_REGION;
    const account = process.env.AWS_ACCOUNT_ID;

    // Note: could optimize with sqs.sendMessageBatch, but that also requires
    //   confident in handling partial failures. KISS for now.
    event.Records.forEach(record => {
        const body = JSON.parse(record.body);
        const name = `${body.source}_${body.type}_queue`;
        const url = `https://sqs.${region}.amazonaws.com/${account}/${name}`;
        console.log(`SQS Endpoint: ${url}`);

        const sqs_request = {
            MessageBody: body,
            QueueUrl: url
        }
        SQS.sendMessage(sqs_request, (err, sqs_response) => {
            if (err) {
                console.log("Error", err);
            } else {
                console.log("Message sent", sqs_response.MessageId);
            }
        })
    })

    callback(null, 'great success');
}