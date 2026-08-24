'use strict';

const { supabaseAdmin } = require('../config/supabase');
const { ok, badRequest, serverError } = require('../utils/response');

/**
 * POST /api/v1/kyc/vahan
 * Body: { vehicle_number }
 */
async function processVahan(req, res) {
  try {
    const { vehicle_number } = req.body;
    const userId = req.user.id;

    if (!vehicle_number) {
      return badRequest(res, 'vehicle_number is required.');
    }

    // ==============================================================================
    // REAL-TIME VAHAN API CALL (Simulated for Development)
    // In production, we securely pass process.env.SUREPASS_API_KEY via Axios here.
    // ==============================================================================
    console.log(`\n[VAHAN API] 🚀 Securely Fetching RC Details for: ${vehicle_number}`);
    
    // Mock Payload mapping exactly to Sprint 1 SQL Migration
    const mockVahanResponse = {
      fuel_type: vehicle_number.toUpperCase().includes('EV') ? 'EV' : 'Petrol',
      seating_capacity: 4, 
      insurance_expiry_date: '2027-12-31',
      puc_expiry_date: '2027-06-30',
      vehicle_exterior_photo_url: 'https://placehold.co/600x400/png?text=Vahan+Verified+Car',
    };

    // 1. Check if vehicle exists for user
    let { data: existingVehicle } = await supabaseAdmin
      .from('vehicles')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

    if (existingVehicle) {
      // Update existing
      const { error: updateErr } = await supabaseAdmin
        .from('vehicles')
        .update({
          vehicle_number: vehicle_number,
          fuel_type: mockVahanResponse.fuel_type,
          seating_capacity: mockVahanResponse.seating_capacity,
          insurance_expiry_date: mockVahanResponse.insurance_expiry_date,
          puc_expiry_date: mockVahanResponse.puc_expiry_date,
          vehicle_exterior_photo_url: mockVahanResponse.vehicle_exterior_photo_url,
          rc_verified: true, // Auto-verified by API!
          updated_at: new Date().toISOString()
        })
        .eq('id', existingVehicle.id);
      
      if (updateErr) return serverError(res, updateErr, 'Failed to update vehicle data.');
    } else {
      // Insert new vehicle
      const { error: insertErr } = await supabaseAdmin
        .from('vehicles')
        .insert({
          user_id: userId,
          vehicle_number: vehicle_number,
          vehicle_model: 'Verified by Vahan',
          fuel_type: mockVahanResponse.fuel_type,
          seating_capacity: mockVahanResponse.seating_capacity,
          insurance_expiry_date: mockVahanResponse.insurance_expiry_date,
          puc_expiry_date: mockVahanResponse.puc_expiry_date,
          vehicle_exterior_photo_url: mockVahanResponse.vehicle_exterior_photo_url,
          rc_verified: true,
        });
        
      if (insertErr) return serverError(res, insertErr, 'Failed to insert vehicle data.');
    }

    // 2. Mark user as a verified driver in the database
    await supabaseAdmin
      .from('users')
      .update({ is_driver: true })
      .eq('id', userId);

    return ok(res, mockVahanResponse, 'Vahan verification successful. Vehicle details saved.');
  } catch (err) {
    return serverError(res, err);
  }
}

module.exports = {
  processVahan,
};
