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

    event.Records.forEach(record => {
        const body = JSON.parse(record.body);
        const name = `${body.source}_${body.type}_queue`
        const url = `https://sqs.${region}.amazonaws.com/${account}/${name}`
        console.log(url);
    })
    callback(null, 'great success');
}