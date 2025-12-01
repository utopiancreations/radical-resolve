import { GoogleGenerativeAI } from "@google/generative-ai";
import dotenv from "dotenv";
import fs from 'fs';

dotenv.config();

const API_KEY = process.env.GEMINI_API_KEY;

if (!API_KEY || API_KEY === 'YOUR_API_KEY_HERE') {
  console.error("Error: GEMINI_API_KEY is missing or invalid in .env file.");
  process.exit(1);
}

const genAI = new GoogleGenerativeAI(API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

// Helper function to call Gemini
async function callGemini(systemInstruction, userInput) {
  console.log("Calling Gemini API...");
  try {
    const result = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: userInput }] }],
      systemInstruction: { role: "system", parts: [{ text: systemInstruction }] },
    });
    return result.response.text();
  } catch (error) {
    console.error("Error calling Gemini:", error);
    return "Error generating response.";
  }
}

// Agent 1: The Validator
const validatorInstruction = `You are an expert in empathetic listening. Your ONLY goal is to validate the user's emotions. Read the input and identify the core feelings (anger, sadness, fear, etc.). Return a response that says: 'I hear that you are feeling [Emotion] because [Reason]. It makes sense that you feel this way.' Do NOT offer advice. Do NOT try to fix it. Keep it under 50 words.`;

// Agent 2: The Objective Observer
const observerInstruction = `You are a purely logical observer, like a Vulcan. Read the input and strip away all adjectives, judgments, and emotional language. List ONLY the objective, indisputable facts of what physically happened. Format the output as a bulleted list of events. If a user says 'He rudely ignored me,' you translate it to 'He did not respond verbally.' Keep it strictly factual.`;

// Agent 3: The Radical Acceptor (FINAL POLISH)
const acceptorInstruction = `You are a wise teacher of Radical Acceptance. 
Context: The user has just been validated (Agent 1) and shown the objective facts (Agent 2).
Goal: Provide a single, powerful statement that pivots from "fighting reality" to "accepting reality."

Rules:
1. Do NOT re-summarize the specific events in detail. Refer to them as "this situation" or "this reality" or a very brief 3-word summary.
2. Acknowledge the validity of the emotion quickly.
3. Focus 80% of the response on the *pivot*: accepting that the past cannot be changed and looking at the present moment.
4. Max 2 sentences.

Example Output: "Your anger is a natural response to this reality, but fighting what has already happened only increases your suffering. Take a deep breath—what is one constructive thing you can do for yourself right now?"`;

function log(message) {
  console.log(message);
  fs.appendFileSync('debug_output.txt', message + '\n');
}

async function main() {
  let userConflict = process.argv[2];

  if (!userConflict) {
    log("Please provide a conflict string or file path as an argument.");
    log("Usage: node index.js \"My conflict string...\" or node index.js conflict.txt");
    return;
  }

  if (fs.existsSync(userConflict)) {
    log("Reading conflict from file: " + userConflict);
    userConflict = fs.readFileSync(userConflict, 'utf-8');
  }

  log("Processing conflict: " + userConflict);
  log("--------------------------------------------------");

  try {
    // Parallel calls for Agent 1 and Agent 2
    log("Running Agent 1 (Validator) and Agent 2 (Observer)...");
    const [validatorResponse, observerResponse] = await Promise.all([
      callGemini(validatorInstruction, userConflict),
      callGemini(observerInstruction, userConflict),
    ]);

    log("\n--- Agent 1: The Validator ---");
    log(validatorResponse);

    log("\n--- Agent 2: The Objective Observer ---");
    log(observerResponse);

    // Agent 3 call
    log("\nRunning Agent 3 (Radical Acceptor)...");
    const synthesisInput = `
    Validation:
    ${validatorResponse}

    Facts:
    ${observerResponse}
    `;

    const acceptorResponse = await callGemini(acceptorInstruction, synthesisInput);

    log("\n--- Agent 3: The Radical Acceptor ---");
    log(acceptorResponse);

  } catch (error) {
    log("An error occurred during processing: " + error);
  }
}

main();
