import {
  RekognitionClient,
  CompareFacesCommand,
} from "@aws-sdk/client-rekognition";

export const createRekognitionClient = () => new RekognitionClient({});
