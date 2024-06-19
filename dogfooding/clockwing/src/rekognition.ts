import {
  RekognitionClient,
  CreateCollectionCommand,
} from "@aws-sdk/client-rekognition";

// global.URL = require("node:url").URL;

export const create_collection_private = async (collectionId: string) => {
  const client = new RekognitionClient({});
  const command = new CreateCollectionCommand({
    CollectionId: collectionId,
  });
  return await client.send(command);
};
