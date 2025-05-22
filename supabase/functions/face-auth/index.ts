import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

serve(async (req) => {
  try {
    console.log('=== Face Auth Function Start ===');
    console.log('Request method:', req.method);
    console.log('Request URL:', req.url);

    const { email } = await req.json();
    console.log('Received email:', email);
    
    if (!email) {
      console.log('Error: Email is missing');
      return new Response(
        JSON.stringify({ error: "Email is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Créer un client Supabase avec les credentials de service
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Récupérer le mot de passe de l'utilisateur
    const { data: user, error } = await supabaseClient
      .from('users')
      .select('password')
      .eq('email', email)
      .single();

    if (error || !user) {
      console.log('Error fetching user:', error);
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log('User found, returning password');
    return new Response(
      JSON.stringify({ password: user.password }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error('=== Error in face-auth function ===');
    console.error('Error type:', error.constructor.name);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    
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