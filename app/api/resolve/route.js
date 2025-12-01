import { GoogleGenerativeAI } from "@google/generative-ai";
import { NextResponse } from "next/server";

const API_KEY = process.env.GEMINI_API_KEY;
const genAI = new GoogleGenerativeAI(API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

// --- AGENT 0: THE CRISIS MONITOR (4-Tier Safety System) ---
const safetyInstruction = `You are a Crisis Classification System.
Analyze the user's input and classify it into one of four categories:

1. "EMERGENCY_SELF"
   - Criteria: The user expresses an *immediate* intent to harm THEMSELVES.
2. "EMERGENCY_VIOLENCE"
   - Criteria: The user expresses an *immediate* intent to harm OTHERS.
3. "DISTRESS"
   - Criteria: The user expresses deep pain, hopelessness, or passive suicidal ideation (e.g., "I don't want to be here anymore"). 
   - IMPORTANT: They are *not* stating an immediate plan to act.
4. "SAFE"
   - Criteria: Normal venting, conflict discussion, anger, or sadness without specific actionable threats.

Output ONLY the category name: "EMERGENCY_SELF", "EMERGENCY_VIOLENCE", "DISTRESS", or "SAFE".`;

// --- AGENT 1: The Compassionate Witness (Warm Validation) ---
const validatorInstruction = `You are a Compassionate Witness. 
Your goal is to make the user feel deeply heard and understood. 
- Avoid robotic phrases like "I hear that you are..." or "It makes sense that..."
- Instead, speak naturally. Reflect the emotional weight of what they shared. 
- Acknowledge the specific difficulty of their situation.
- Keep it warm, human, and concise (under 75 words).`;

// --- AGENT 2: The Grounded Realist (Narrative Summary) ---
const observerInstruction = `You are a Grounded Realist. 
Your goal is to summarize the *situation* without the emotional "story."
- Provide a 3-5 sentence narrative summary of the core facts.
- Strip away the judgments (e.g., "She gaslit me" becomes "She denied your version of events").
- Focus on the *actions* that occurred, not the *interpretations*.
- Keep it brief and strictly factual, but conversational.`;

// --- AGENT 3: The Radical Acceptor (Closure Detection) ---
const acceptorInstruction = `You are a wise mentor in Radical Acceptance. 
Context: The user has been validated and grounded in reality.
Goal: Provide a closing insight.

### STEP 1: DETECT CLOSURE
Analyze the User's Input, specifically the *end* of their message.
- Did they state a decision? (e.g., "I am deleting the app", "I am blocking him")
- Did they set a boundary?

**IF CLOSURE IS DETECTED (The User has acted):**
- Output Header: "### 💡 Actionable Insight"
- Do not ask a question.
- Affirm their decision as an act of Radical Acceptance.
- Remind them that peace comes from maintaining this boundary.

**IF CLOSURE IS ABSENT (The User is stuck/venting):**
- Output Header: "### 🌱 Radical Acceptance"
- Pivot them from "why is this happening?" to "this is happening."
- Ask a gentle question to help them find one small thing they can control right now.`;

// --- AGENT 4: The Coach (Follow-up Conversations) ---
const coachInstruction = `You are a wise and warm conflict resolution coach. 
Output Format:
### ❤️ Validation
(Warmly validate their feelings in 1-2 sentences.)

### 📷 The Reality
(Briefly summarize the *current* objective situation in 2-3 sentences.)

### [Dynamic Header]
(Choose based on logic below)

LOGIC:
- If the user has made a decision -> Use "### 💡 Actionable Insight".
- If the user is spiraling or asking "what should I do?" -> Use "### 🌱 Radical Acceptance".`;

// --- PRIVACY & LOGGING UTILITIES ---
// This function strips common PII to ensure training data is safer.
function scrubPII(text) {
    if (!text) return "";
    let scrubbed = text;
    // Scrub Emails
    scrubbed = scrubbed.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, "[EMAIL]");
    // Scrub Phone Numbers (US formats mostly)
    scrubbed = scrubbed.replace(/(\+\d{1,2}\s?)?1?\-?\.?\s?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}/g, "[PHONE]");
    return scrubbed;
}

async function logConversation(userInput, aiOutput, safetyStatus, userConsent = false) {
    // 1. If user did not consent, DO NOT LOG anything.
    if (!userConsent) return;

    // 2. Scrub PII from both inputs and outputs
    const safeInput = scrubPII(userInput);
    const safeOutput = scrubPII(aiOutput);

    // 3. Construct the Fine-Tuning Entry (JSONL style)
    const logEntry = {
        timestamp: new Date().toISOString(),
        safety_tier: safetyStatus,
        messages: [
            { role: "user", content: safeInput },
            { role: "model", content: safeOutput }
        ]
    };

    // 4. SAVE TO DATABASE (Placeholder)
    // In production, you would call Supabase/Firebase/Postgres here.
    // For now, we will just console log the JSON object so you can see it in your server logs.
    console.log(">> FINE-TUNE LOG:", JSON.stringify(logEntry));

    // Example Supabase Implementation:
    // await supabase.from('training_logs').insert(logEntry);
}


// Helper functions
async function callGemini(systemInstruction, userInput) {
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

async function callGeminiChat(systemInstruction, history, userInput) {
    try {
        const chat = model.startChat({
            history: history,
            systemInstruction: { role: "system", parts: [{ text: systemInstruction }] },
        });
        const result = await chat.sendMessage(userInput);
        return result.response.text();
    } catch (error) {
        console.error("Error calling Gemini Chat:", error);
        return "Error generating response.";
    }
}


export async function POST(request) {
    try {
        const { messages, dataCollectionConsent } = await request.json(); // Accept consent flag from frontend

        if (!messages || messages.length === 0) {
            return NextResponse.json({ error: "Messages are required" }, { status: 400 });
        }

        const lastUserMessage = messages[messages.length - 1].content;

        // --- STEP 1: SAFETY CHECK ---
        let safetyStatus = await callGemini(safetyInstruction, lastUserMessage);
        safetyStatus = safetyStatus.trim();

        // 🔴 EMERGENCY TYPE 1: SELF-HARM
        if (safetyStatus.includes("EMERGENCY_SELF")) {
            return NextResponse.json({
                role: 'assistant', content: `
### 🆘 Immediate Support
I hear how much pain you are in, and I want to ensure you are safe. I am an AI, not a mental health professional, and your safety is the most important thing right now.

Please reach out to a human who can help you through this moment:
* **🇺🇸 US:** Call or Text **988** (Suicide & Crisis Lifeline)
* **🌍 International:** Please contact your local emergency services immediately.
             ` });
        }

        // 🔴 EMERGENCY TYPE 2: VIOLENCE TO OTHERS
        if (safetyStatus.includes("EMERGENCY_VIOLENCE")) {
            return NextResponse.json({
                role: 'assistant', content: `
### ⛔ Safety Alert
I hear the intensity of your anger, but I cannot support or facilitate violence against others. Safety is the priority here.

If you feel you are in immediate danger of acting on these impulses, please contact your local emergency services immediately.
             ` });
        }

        // --- STEP 2: NORMAL PROCESSING ---
        let finalResponse = "";

        if (messages.length === 1) {
            const [validatorResponse, observerResponse] = await Promise.all([
                callGemini(validatorInstruction, lastUserMessage),
                callGemini(observerInstruction, lastUserMessage),
            ]);

            const synthesisInput = `
            User Input: "${lastUserMessage}"
            Validation: ${validatorResponse}
            Facts: ${observerResponse}
            `;

            const acceptorResponse = await callGemini(acceptorInstruction, synthesisInput);

            finalResponse = `
### ❤️ Validation
${validatorResponse}

### 📷 The Reality
${observerResponse}

${acceptorResponse}
            `;

        } else {
            const history = messages.slice(0, -1).map(msg => ({
                role: msg.role === 'user' ? 'user' : 'model',
                parts: [{ text: msg.content }],
            }));

            finalResponse = await callGeminiChat(coachInstruction, history, lastUserMessage);
        }

        // 🟡 DISTRESS: Append Resources
        if (safetyStatus.includes("DISTRESS")) {
            finalResponse += `\n\n---\n*Note: You mentioned feeling heavy things. If you ever feel like you can't go on, free, confidential support is available 24/7 by calling or texting 988 (US).*`;
        }

        // --- STEP 3: PRIVACY-FIRST LOGGING ---
        // We do this asynchronously so we don't block the response to the user
        // Note: In Serverless functions, await is safer to ensure it completes before spin-down.
        await logConversation(lastUserMessage, finalResponse, safetyStatus, dataCollectionConsent);

        return NextResponse.json({ role: 'assistant', content: finalResponse });

    } catch (error) {
        console.error("API Error:", error);
        return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
}
