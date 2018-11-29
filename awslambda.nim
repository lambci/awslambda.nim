import os, httpclient, json, strutils

type
  LambdaContext* = tuple
    functionName: string
    functionVersion: string
    memoryLimitInMb: int
    logGroupName: string
    logStreamName: string
    awsRequestId: string
    invokedFunctionArn: string
    deadlineMs: int
    identity: JsonNode
    clientContext: JsonNode

let functionName = string(getEnv("AWS_LAMBDA_FUNCTION_NAME"))
let functionVersion = string(getEnv("AWS_LAMBDA_FUNCTION_VERSION"))
let functionMemorySize = parseInt(getEnv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE"))
let logGroupName = string(getEnv("AWS_LAMBDA_LOG_GROUP_NAME"))
let logStreamName = string(getEnv("AWS_LAMBDA_LOG_STREAM_NAME"))
let runtimeBase = "http://" & getEnv("AWS_LAMBDA_RUNTIME_API") & "/2018-06-01/runtime"

proc startLambda*(handler: proc(event: JsonNode, context: LambdaContext): JsonNode) =
  while true:
    var client = newHttpClient()
    var res = client.get(runtimeBase & "/invocation/next")

    if res.code() != Http200:
      raise newException(Exception, "Unexpected response when invoking: " & res.status)

    var event = parseJson(res.body)

    putEnv("_X_AMZN_TRACE_ID", res.headers.getOrDefault("Lambda-Runtime-Trace-Id"))

    var context: LambdaContext
    context = (
      functionName: functionName,
      functionVersion: functionVersion,
      memoryLimitInMb: functionMemorySize,
      logGroupName: logGroupName,
      logStreamName: logStreamName,
      awsRequestId: string(res.headers.getOrDefault("Lambda-Runtime-Aws-Request-Id")),
      invokedFunctionArn: string(res.headers.getOrDefault("Lambda-Runtime-Invoked-Function-Arn")),
      deadlineMs: parseInt(res.headers.getOrDefault("Lambda-Runtime-Deadline-Ms")),
      identity: newJNull(),
      clientContext: newJNull(),
    )

    var clientContext = res.headers.getOrDefault("Lambda-Runtime-Client-Context")
    if clientContext.len != 0:
      context.clientContext = parseJson(clientContext)

    var identity = res.headers.getOrDefault("Lambda-Runtime-Cognito-Identity")
    if identity.len != 0:
      context.identity = parseJson(identity)

    let result = handler(event, context)

    client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    res = client.request(runtimeBase & "/invocation/" & context.awsRequestId & "/response",
                         httpMethod = HttpPost, body = $result)
    if res.code() != Http202:
      raise newException(Exception, "Unexpected response when responding: " & res.status)
