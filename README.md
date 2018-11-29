# Nim on AWS Lambda

Write your Lambda functions in [nim](https://nim-lang.org/) using the [custom
runtime](https://aws.amazon.com/about-aws/whats-new/2018/11/aws-lambda-now-supports-custom-runtimes-and-layers/)
and get tiny binaries (250kb) and single-digit millisecond cold starts!

![Log output](https://raw.githubusercontent.com/lambci/awslambda.nim/master/img/log.png "Log output screenshot")

## Function Example

Create a `bootstrap.nim` with the following:

```nim
import awslambda, json, times

proc handler(event: JsonNode, context: LambdaContext): JsonNode =
  echo "Hi from nim! Invocation will timeout at: ", context.deadline.format("yyyy-MM-dd'T'HH:mm:ss'.'fff")

  event["newKey"] = %*"newVal"

  event


when isMainModule:
  startLambda(handler)
```

## Compiling

```sh
# if you're using Linux, you probably don't need to compile in docker, but assuming you're not:

docker run --rm -v "$PWD":/app -w /app nimlang/nim \
  sh -c 'nimble install -y https://github.com/lambci/awslambda.nim && nim c -d:release bootstrap.nim'

zip -yr lambda.zip bootstrap # and anything else your binary needs
```

Then upload `lambda.zip` as the function code for your (custom runtime) Lambda.

## Documentation

### startLambda

```nim
proc startLambda*(handler: proc(event: JsonNode, context: LambdaContext): JsonNode)
```

This processes the event processing loop and takes a handler proc that should take the form:

```nim
proc handler(event: JsonNode, context: LambdaContext): JsonNode
```

### LambdaContext

Each invocation will also have the following context object populated:

```nim
type
  LambdaContext* = tuple
    functionName: string
    functionVersion: string
    memoryLimitInMb: int
    logGroupName: string
    logStreamName: string
    awsRequestId: string
    invokedFunctionArn: string
    deadline: Time
    identity: JsonNode
    clientContext: JsonNode
```
