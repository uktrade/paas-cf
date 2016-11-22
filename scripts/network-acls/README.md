We use [boto3](https://aws.amazon.com/sdk-for-python/) to talk to aws.
Boto3 is configured automatically using the environment variables or config under `~/.aws` you have already set up for `awscli`.

To run the script, first set up a virtualenv:

```
virtualenv env
source env/bin/activate
pip install -r requirements.txt
```

Then run the script, it should provide usage instructions.
