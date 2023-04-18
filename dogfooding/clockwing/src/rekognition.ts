import {
  RekognitionClient,
  CreateCollectionCommand,
} from "@aws-sdk/client-rekognition";

export const create_collection_private = async (collectionId: string) => {
  const client = new RekognitionClient({});
  const command = new CreateCollectionCommand({
    CollectionId: collectionId,
  });
  return await client.send(command);
};
