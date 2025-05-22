import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

serve(async (req) => {
  try {
    // Log the incoming request
    console.log('Received request:', req.method, req.url);

    const { email } = await req.json();
    console.log('Received email:', email);
    
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const jwtSecret = Deno.env.get("JWT_SECRET");
    console.log('JWT_SECRET exists:', !!jwtSecret);
    
    if (!jwtSecret) {
      throw new Error("JWT_SECRET is not set");
    }

    const payload = {
      sub: email,
      email,
      exp: Math.floor(Date.now() / 1000) + 60 * 60, // 1 hour expiration
    };

    console.log('Creating JWT with payload:', payload);

    const token = await create(
      { alg: "HS256", typ: "JWT" },
      payload,
      jwtSecret
    );

    console.log('JWT created successfully');

    return new Response(
      JSON.stringify({ token }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error('Error in face-auth function:', error);
    
    // Safely handle the error message
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    
    return new Response(
      JSON.stringify({ 
        error: errorMessage,
        details: error instanceof Error ? error.stack : undefined
      }),
      { 
        status: 500, 
        headers: { "Content-Type": "application/json" } 
      }
    );
  }
}); 