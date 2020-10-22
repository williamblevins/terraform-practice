// nodejs12x runtime AWS Lambda function

const aws = require('aws-sdk');
const sqs = new AWS.SQS({apiVersion: '2012-11-05'});

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
    const name = `${event.source}_${event.type}_queue`
    const url = `https://sqs.${region}.amazonaws.com/${account}/${name}`
    console.log(url);
    callback(null, 'great success');
}