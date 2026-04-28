local customRouteSLIs = [
  {
    name: 'server_route_blob_upload_uuid_deletes',
    description: |||
      Delete requests for the registry blob upload endpoints.

      Used to cancel outstanding upload processes, releasing associated
      resources.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.997,
    },
    satisfiedThreshold: 2.5,
    toleratedThreshold: 5,
    route: '/v2/{name}/blobs/uploads/{uuid}',
    methods: ['delete'],
  },
  {
    name: 'server_route_blob_upload_uuid_reads',
    description: |||
      Read requests (GET) for the registry blob upload endpoints.

      GET is used to retrieve the current status of a resumable upload.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.997,
    },
    satisfiedThreshold: 1,
    toleratedThreshold: 2.5,
    route: '/v2/{name}/blobs/uploads/{uuid}',
    // HEAD is currently not part of the spec, but to avoid ignoring it
    // if it was introduced, we include it here.
    methods: ['get', 'head'],
    trafficCessationAlertConfig: false,
  },
  {
    name: 'server_route_blob_upload_uuid_writes',
    description: |||
      Write requests (PUT or PATCH) for the registry blob upload endpoints.

      PUT is used to complete the upload specified by uuid, optionally appending
      the body as the final chunk.

      PATCH is used to upload a chunk of data for the specified upload.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.97,
    },
    satisfiedThreshold: 25,
    toleratedThreshold: 60,
    route: '/v2/{name}/blobs/uploads/{uuid}',
    // POST is currently not part of the spec, but to avoid ignoring it if it was
    // introduced, we include it here.
    methods: ['put', 'patch', 'post'],
  },
  {
    name: 'server_route_blob_digest_deletes',
    description: |||
      Delete requests for the blob digest endpoints on
      the registry.

      Used to delete blobs identified by name and digest.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.999,
    },
    satisfiedThreshold: 0.5,
    toleratedThreshold: 2.5,
    route: '/v2/{name}/blobs/{digest}',
    methods: ['delete'],
  },
  {
    name: 'server_route_blob_digest_reads',
    description: |||
      All read-requests (GET or HEAD) for the blob endpoints on
      the registry.

      GET is used to pull a layer gated by the name of repository
      and uniquely identified by the digest in the registry.

      HEAD is used to check the existence of a layer.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.98,
    },
    satisfiedThreshold: 10,
    toleratedThreshold: 60,
    route: '/v2/{name}/blobs/{digest}',
    methods: ['get', 'head'],
  },
  {
    name: 'server_route_blob_digest_writes',
    description: |||
      Write requests (PUT or PATCH or POST) for the registry blob digest endpoints.

      Currently not part of the spec.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.997,
    },
    satisfiedThreshold: 2.5,
    toleratedThreshold: 25,
    route: '/v2/{name}/blobs/{digest}',
    // PATCH, POST, and PUT are currently not part of the spec, but to avoid ignoring them
    // if they were introduced, we include them here.
    methods: ['patch', 'post', 'put'],
  },
];

{
  /*
  *
  * Returns the unmodified config, this is used in tests to validate that all
  * methods for routes are defined
  */
  customApdexRouteConfig:: customRouteSLIs,
}
