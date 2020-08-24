Tezos auxiliary cluster
=======================

This repository is part of the [Tezos Suite by MIDL.dev](https://tezos-docs.midl.dev/)

This is a set of terraform and kubernetes code to deply a tezos node in k8s that performs the following operations:

* monitors a baking operation with [Tezos Network Monitor](https://gitlab.com/polychainlabs/tezos-network-monitor)
* sends payouts from a hot wallet with Backerei. The key is stored in a Kubernetes secret.
* deploys a baking website

How to deploy
-------------

Follow instructions in [Tezos suite documentation](https://tezos-docs.midl.dev/deploy-auxiliary-cluster.html)

Monitoring
----------

In addition to internal monitoring of the main baking cluster, it is recommended to monitor the baking operations from a node that is completely separated from the baking infrastructure. A good option is to set up a completely separate Kubernetes cluster, and run Tezos-network-monitor on it, this way it is administratively separated from the main baking node.

Backerei
--------

Written in Haskell and maintained by Cryptium labs, [Backerei](https://github.com/cryptiumlabs/backerei) performs payout operations at every cycle, with no minimum amount needed. It assumes bakers 100% uptime so payouts are insured for liveness. Cryptium is one of the main bakers so the software is guaranteed to remain up-to-date with the Tezos protocol.

Website
-------

The kubernetes infrastructure is optionally configured to deploy a static Jekyll website in a GCP storage bucket.

This allows you to build your baker's website where delegates can check their contribution and payouts.

You can pass a `website` variable to terraform to make that happen.

You will have to configure your DNS registrar to point to the Google nameservers.
