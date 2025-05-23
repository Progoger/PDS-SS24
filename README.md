# PDS-SS24
A causally consistent CRDT database

Final project for lecture course on Programming Distributed Systems in summer semester in 2024.

Database should be able to run replicated on multiple (2 - 10) machines. Each replica is a full replica (eventually) storing all the data. The database must be highly available and provide low latency, so every replica should be able to handle requests, even if it is temporarily disconnected from others.

Data model: Minidote is a key-CRDT store: Each replicated data object is stored under a key. The store provides an API to read the current state of an object given a key and to update objects. The supported update operations depend on the data type of the object. For example a counter supports increment- and decrement operations, while a set supports add- and remove-operations.

Using Antidote CRDT library to support a variety of replicated data types.

Additional extension - Robustness:

• An implementation should ensure that whenever possible, a signal dispatched to a process should eventually arrive at it. There are situations when it is not reasonable to require that all signals arrive at their destination, in particular when a signal is sent to a process on a different node and communication between the nodes is temporarily lost.

• When a node crashes we want to be able to restart it and continue working.
