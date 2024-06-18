const serverless = require("serverless-http");
const express = require("express");
const VoiceResponse = require("twilio").twiml.VoiceResponse;
const bodyParser = require("body-parser");

const createApp = (baseUrl) => {
  const app = express();
  app.use(bodyParser.urlencoded({ extended: true }));

  // const baseUrl = process.env.BASE_URL || 'https://XXXXXXXX.execute-api.us-east-1.amazonaws.com/dev';

  app.all("/", (request, response) => {
    response.type("xml");
    const twiml = new VoiceResponse();
    twiml.say("Welcome to Miguel's calendar");
    const gather = twiml.gather({
      input: "dtmf",
      action: `${baseUrl}/results`,
      speechTimeout: "auto",
    });
    gather.say(
      'Please press 1 to schedule a meeting with Miguel. <break time=".25s"/> Press 2 to cancel a meeting. <break time=".25s"/> Press 3 to re-schedule a meeting.'
    );
    console.log(twiml.toString());
    response.send(twiml.toString());
  });

  app.all("/results", (request, response) => {
    console.log("results");
    response.type("xml");
    const twiml = new VoiceResponse();
    console.log(request.body);
    const digits = request.body.Digits;

    switch (digits) {
      case "1":
        twiml.redirect(`${baseUrl}/meetings/create`);
        break;
      case "2":
        twiml.redirect(`${baseUrl}/meetings/cancel`);
        break;
      case "3":
        twiml.redirect(`${baseUrl}/meetings/update`);
        break;
      default:
        twiml.say("Invalid option. Please try again.");
        twiml.redirect(`${baseUrl}/`);
        break;
    }

    response.send(twiml.toString());
  });

  app.post("/meetings/create", (request, response) => {
    console.log("create");
    const twiml = new VoiceResponse();
    twiml.say("You have chosen to schedule a meeting with Miguel.");
    const gather = twiml.gather({
      input: "speech dtmf",
      finishOnKey: "#",
      action: `${baseUrl}/meetings/create/date-time`,
    });
    gather.say(
      "Please say or enter the date and time of the meeting followed by the pound key."
    );
    response.type("text/xml");
    response.send(twiml.toString());
  });

  app.post("/meetings/create/date-time", (request, response) => {
    console.log("Received request at /meetings/create/date-time");
    const twiml = new VoiceResponse();
    const dateTime = request.body.SpeechResult || request.body.Digits;

    console.log("Date and time received:", dateTime);

    if (request.body.Digits) {
      twiml.say(
        `You entered ${request.body.Digits}. Please say timezone followed by the pound key.`
      );
    } else {
      twiml.say(
        `You said ${request.body.SpeechResult}. Please say your timezone followed by the pound key.`
      );
    }

    const gather = twiml.gather({
      input: "speech dtmf",
      finishOnKey: "#",
      action: `${baseUrl}/meetings/create/timezone`,
    });
    response.type("text/xml");
    response.send(twiml.toString());
  });

  app.post("/meetings/create/timezone", (request, response) => {
    console.log("Received request at /meetings/create/timezone");
    const twiml = new VoiceResponse();
    const timezone = request.body.SpeechResult || request.body.Digits;

    console.log("Timezone received:", timezone);

    if (timezone) {
      twiml.say(`You entered ${timezone}.`);
    } else {
      twiml.say("Invalid input. Please try again.");
      twiml.redirect(`${baseUrl}/meetings/create`);
    }

    twiml.say(
      'Thank you for providing the details. <break time=".25s"/> Your meeting has been scheduled.<break time=".25s"/> Have a great day. <break time=".25s"/>);'
    );
    response.type("text/xml");
    response.send(twiml.toString());
  });

  app.post("/meetings/cancel", (request, response) => {
    console.log("Received request at /meetings/cancel");
    const twiml = new VoiceResponse();
    twiml.say(
      "You have chosen to cancel an already scheduled meeting. This functionality is not yet implemented. Please try again later."
    );
    response.type("text/xml");
    response.send(twiml.toString());
  });

  app.post("/meetings/update", (request, response) => {
    console.log("Received request at /meetings/update");
    const twiml = new VoiceResponse();
    twiml.say(
      "You have chosen to change a meeting. This functionality is not yet implemented. Please try again later."
    );
    response.type("text/xml");
    response.send(twiml.toString());
  });

  return serverless(app);
};

module.exports.createApp = createApp;

// module.exports.app = serverless(app);
