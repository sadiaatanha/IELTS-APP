// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { module, question, answer } = await req.json();

    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Gemini API key missing",
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const prompt = `
You are a strict IELTS Writing examiner.

Evaluate the student's IELTS Writing answer using official IELTS band descriptors.

Module: ${module}

Question:
${question}

Student Answer:
${answer}

Rules:
- Give a realistic IELTS band score from 0 to 9.
- Use 0.5 increments only, for example 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0.
- Do not give the same band score every time.
- Do not be overly generous.
- A poor, incomplete, memorized, irrelevant, or very short answer should receive a low band.
- A Band 9 answer must be excellent in task response, coherence, vocabulary, and grammar.
- Return ONLY valid JSON.
- Do not use markdown.
- Do not wrap JSON in triple backticks.

Return this JSON structure:

{
  "band_score": "",
  "task_response": "",
  "coherence": "",
  "lexical_resource": "",
  "grammar": "",
  "overall_feedback": "",
  "improvement_tips": []
}
`;

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt,
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.4,
            responseMimeType: "application/json",
          },
        }),
      },
    );

    const data = await geminiResponse.json();

    if (!geminiResponse.ok) {
      return new Response(
        JSON.stringify({
          success: false,
          error: data,
        }),
        {
          status: geminiResponse.status,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const feedbackText =
      data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!feedbackText) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "No feedback returned from Gemini",
          raw: data,
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    let feedback;

    try {
      feedback = JSON.parse(feedbackText);
    } catch (_) {
      feedback = feedbackText;
    }

    return new Response(
      JSON.stringify({
        success: true,
        feedback,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});