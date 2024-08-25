# Constant Function Market Maker(CFMM) 
This project is about the combination of the fully homomorphic encryption with CFMM in order to provide a safe automated market maker version.
!Note though that to make this work, you must use your `INFURA_API_KEY` and your `MNEMONIC` as GitHub secrets.

## Pre Requisites

Before being able to run any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as an environment variable. You can follow the example in `.env.example` and start with the following command:

```sh
cp .env.example .env
```

If you don't already have a mnemonic, you can use this [website](https://iancoleman.io/bip39/) to generate one.

Then, proceed with installing dependencies - please **_make sure to use Node v20_** or more recent or this will fail:

```
npm install
```

### Start fhEVM local development env
```
npm fhevm:start
```
