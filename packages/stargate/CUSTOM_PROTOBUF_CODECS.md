# Custom Protocol Buffer Codecs

As of [v0.40](https://github.com/cosmos/cosmos-sdk/releases/tag/v0.40.0), the
Cosmos SDK uses
[protocol buffers](https://developers.google.com/protocol-buffers) as its
standard serialization format for blockchain state and wire communication.
CosmJS by default supports protocol buffer serialization for many of the
standard queries and messages defined by the Cosmos SDK, as well as
[CosmWasm](https://github.com/CosmWasm/wasmd). This document explains how you
can make use of protocol buffer serialization for your own custom modules with
CosmJS.

## Prerequisites

- You are working on a TypeScript project (plain JS is possible but not covered
  by this document).
- You have installed `@cosmjs/proto-signing`, `@cosmjs/stargate` and
  `@cosmjs/tendermint-rpc` as dependencies.
- You have installed `ts-proto` as a development dependency.
- You have installed [`protoc`](https://github.com/protocolbuffers/protobuf).
- This document assumes that the protocol buffer definitions which you need are
  already available somewhere in `.proto` files.

## Step 1: Acquire the definition files

You will need these files locally. For example, we use
[this script](https://github.com/cosmos/cosmjs/blob/v0.25.0-alpha.0/packages/stargate/scripts/get-proto.sh)
to download the definition files from the Cosmos SDK repository.

## Step 2: Generate codec files

In CosmJS we use [ts-proto](https://github.com/stephenh/ts-proto) to generate
codec files, and in this document we assume you will follow the same route. Here
is an example usage:

```sh
protoc \
  --plugin="./node_modules/.bin/protoc-gen-ts_proto" \
  --ts_proto_out="./path/to/output/directory" \
  --proto_path="./path/to/definitions" \
  --ts_proto_opt="esModuleInterop=true,forceLong=long,useOptionals=true" \
  "./path/to/definitions/file.proto" \
  "./path/to/definitions/another.proto"
```

Note that the available `ts-proto` options are described
[here](https://github.com/stephenh/ts-proto#supported-options). You can see the
script we use for the `@cosmjs/stargate` package
[here](https://github.com/cosmos/cosmjs/blob/v0.25.0-alpha.0/packages/stargate/scripts/define-proto.sh).

## Step 3a: Instantiate a signing client using your custom message types

This section assumes that your definition files included `MsgXxx` `message`
definitions for use in submitting transactions to a Cosmos SDK blockchain. You
can instantiate a signing client for Stargate which supports those message types
using a custom registry. We expose a `Registry` class from
`@cosmjs/proto-signing` for you to use, which maps type URLs to codec objects.
For example:

```ts
import { DirectSecp256k1HdWallet, Registry } from "@cosmjs/proto-signing";
import { defaultRegistryTypes, SigningStargateClient } from "@cosmjs/stargate";
import { MsgXxx } from "./path/to/generated/codec";

const myRegistry = new Registry([
  ...defaultRegistryTypes,
  ["/my.custom.MsgXxx", MsgXxx],
]);
const mnemonic =
  "economy stock theory fatal elder harbor betray wasp final emotion task crumble siren bottom lizard educate guess current outdoor pair theory focus wife stone";

// Inside an async function...
const signer = await DirectSecp256k1HdWallet.fromMnemonic(
  mnemonic,
  undefined,
  "myprefix",
);
const client = await SigningStargateClient.connectWithSigner(
  "my.endpoint.com",
  signer,
  {
    registry: myRegistry,
  },
);
```

Now when you want to sign and broadcast a transaction which contains a message
of your custom type, the client will know how to serialize (and deserialize) it:

```ts
const myAddress = "wasm1pkptre7fdkl6gfrzlesjjvhxhlc3r4gm32kke3";
const message = {
  typeUrl: "/my.custom.MsgXxx",
  value: {
    foo: "bar",
  },
};
const fee = {
  amount: [
    {
      denom: "udenom",
      amount: "120000",
    },
  ],
  gas: "10000",
};

// Inside an async function...
// This method uses the registry you provided
const response = await client.signAndBroadcast(myAddress, [message], fee);
```

You can see a more complete example in Confio’s
[`ts-relayer` repo](https://github.com/confio/ts-relayer/blob/1200f6f998edb2fed6c595aefd39b2e12de4972a/src/lib/ibcclient.ts).

### Step 3b: Instantiate a query client using your custom query service

This section assumes that your definition files included a `Query` `service`
with `rpc` methods. `ts-proto` will generate a `QueryClientImpl` class which
needs to be provided with an RPC client.

Creating an RPC client with the functionality required by this generated class
currently requires a few layers of abstraction. Here is how you can achieve it
using CosmJS helpers:

```ts
import { createRpc, QueryClient } from "@cosmjs/stargate";
import { Tendermint34Client } from "@cosmjs/tendermint-rpc";
import { QueryClientImpl } from "./path/to/generated/codec";

// Inside an async function...
// The Tendermint client knows how to talk to the Tendermint RPC endpoint
const tendermintClient = await Tendermint34Client.connect("my.endpoint.com");

// The generic Stargate query client knows how to use the Tendermint client to submit unverified ABCI queries
const queryClient = new QueryClient(tendermintClient);

// This helper function wraps the generic Stargate query client for use by the specific generated query client
const rpcClient = createRpc(queryClient);

// Here we instantiate a specific query client which will have the custom methods defined in the .proto file
const queryService = new QueryClientImpl(rpcClient);

// Now you can use this service to submit queries
const queryResult = await queryService.MyCustomQuery({
  foo: "bar",
});
```

Additionally, we provide a system for extending `@cosmjs/stargate`’s
`QueryClient` with methods of your own design, wrapping those of the query
service. For this you will need to define your own `setupXxxExtension` functions
and pass them to the `QueryClient.withExtensions` static method like this:

```ts
// Define your extensions
function setupXxxExtension(base: QueryClient) {
  const rpcClient = createRpc(base);
  const queryService = new QueryClientImpl(rpcClient);

  return {
    my: {
      nested: {
        customQuery: async (foo: string) =>
          queryService.MyCustomQuery({ foo: foo }),
      },
    },
  };
}
function setupYyyExtension(base: QueryClient) {
  // ...
}

// Setup the query client
const queryClient = QueryClient.withExtensions(
  tendermintClient,
  setupXxxExtension,
  setupYyyExtension,
  // You can add up to 8 extensions
);

// Inside an async function...
// Now your query client has been extended
const queryResult = await queryClient.my.nested.customQuery("bar");
```

You can see how CosmJS sets up the `bank` extension for its default query client
[here](https://github.com/cosmos/cosmjs/blob/v0.25.0-alpha.0/packages/stargate/src/queries/bank.ts).