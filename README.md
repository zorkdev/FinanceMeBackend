# FinanceMe Backend

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-blue.svg)

## 🛠 Branching Strategy

Use `develop` branch for development and `master` for release. Pushing to develop automatically deploys to the staging environment, pushing to master deploys to production.

## 🚀 Build Instructions

This project uses the [Vapor](https://github.com/vapor/vapor) web framework and the [Swift Package Manager](https://github.com/apple/swift-package-manager) for dependencies. Build instructions:

``` bash
$ git clone https://github.com/zorkdev/FinanceMeBackend.git
$ cd FinanceMeBackend
$ open Package.swift
```

To lint and test the project use the `test.sh` script.

Environment variables required:

`APNS_CERT`: Certificate for APNS  
`APNS_CERT_PW`: Password for APNS certificate  
`DATABASE_URL`: URL of the database
