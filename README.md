#Telehash for Objective-C#

## migration from v2 -> v3 progress

TODO:

* refactor THPath into THPipe, clean up transports
* update cs2a/cs3a encodings
* handle multiple handshakes to app callback
* rework e3x interface/abstraction to match the spec api
* reorg how the peer/connect works (only need send/receive, not relay to start)

DONE:

* renamed THCipherSet* to E3XCipherSet*
* renamed THChannel* to E3XChannel*
* renamed THLine to E3XExchange
* renamed THIdentity to THLink
* renamed THSwitch to THMesh
* removed THMeshBuckets, casualties of "seek" and "link" channel handlers


Using with CocoaPods
--------------------

To install with CocoaPods, simply add the following to your Podfile:

pod 'Telehash', '0.0.1'

Using as a standalone library
-----------------------------

See the sub-project thFieldTest for an example of using the library.
