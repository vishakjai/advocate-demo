local customRouteSLIs = [
  {
    name: 'server_route_manifest_reads',
    description: |||
      All read-requests (HEAD or GET) for the manifest endpoints on
      the registry.
      Fetch the manifest identified by name and reference where reference can be
      a tag or digest. A HEAD request can also be issued to this endpoint to
      obtain resource information without receiving all data.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.999,
    },
    satisfiedThreshold: 0.25,
    toleratedThreshold: 0.5,
    route: '/v2/{name}/manifests/{reference}',
    methods: ['get', 'head'],
  },
  {
    name: 'server_route_manifest_writes',
    description: |||
      All write-requests (put, delete) for the manifest endpoints on
      the registry.

      Put the manifest identified by name and reference where reference can be
      a tag or digest.

      Delete the manifest identified by name and reference. Note that a manifest
      can only be deleted by digest.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.995,
    },
    satisfiedThreshold: 1,
    toleratedThreshold: 2.5,
    route: '/v2/{name}/manifests/{reference}',
    // POST and PATCH are currently not part of the spec, but to avoid ignoring
    // them if they were introduced, we include them here.
    methods: ['put', 'delete', 'post', 'patch'],
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
    name: 'server_route_blob_upload_uuid_deletes',
    description: |||
      Delete requests for the registry blob upload endpoints.

      Used to cancel outstanding upload processes, releasing associated
      resources.
    |||,
    monitoringThresholds+: {
      apdexScore: 0.997,
    },
    satisfiedThreshold: 3,
    toleratedThreshold: 6,
    route: '/v2/{name}/blobs/uploads/{uuid}',
    methods: ['delete'],
  },
  {
    name: 'server_route_blob_upload_uuid_reads',
    description: |||
      Read requests (GET) for the registry blob upload endpoints.

      GET is used to retrieve the current status of a resumable upload.

      This is currently not used on GitLab.com.
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
];

{
  /*
  *
  * Returns the unmodified config, this is used in tests to validate that all
  * methods for routes are defined
  */
  customApdexRouteConfig:: customRouteSLIs,
}
