Tezos auxiliary cluster
=======================

This repository is part of the [Tezos Suite by MIDL.dev](https://tezos-docs.midl.dev/)

This is a set of terraform and kubernetes code to deply a tezos node in k8s that performs the following operations:

* monitors a baking operation with [Tezos Network Monitor](https://gitlab.com/polychainlabs/tezos-network-monitor)

How to deploy
-------------

Follow instructions in [Tezos suite documentation](https://tezos-docs.midl.dev/deploy-auxiliary-cluster.html)

Monitoring
----------

In addition to internal monitoring of the main baking cluster, it is recommended to monitor the baking operations from a node that is completely separated from the baking infrastructure. A good option is to set up a completely separate Kubernetes cluster, and run Tezos-network-monitor on it, this way it is administratively separated from the main baking node.
