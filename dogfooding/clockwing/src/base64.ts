export const decode = (input: string) => {
  return Buffer.from(input, "base64").toString("binary");
};
