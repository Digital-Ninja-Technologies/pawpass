-- The two state machine lookups are pure, but the database linter wants every function to pin its search path.
alter function private.escrow_can_move(text, text) set search_path = '';
alter function private.booking_can_move(text, text) set search_path = '';
