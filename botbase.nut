// custom vscript bot baseclass
IncludeScript("timer"); // github.com/Squinkz/vscript_timer

// Constrains an angle into [-180, 180] range
function NormalizeAngle(target)
{
	target %= 360.0;
	if (target > 180.0)
		target -= 360.0;
	else if (target < -180.0)
		target += 360.0;
	return target;
}

// Approaches an angle at a given speed
function ApproachAngle(target, value, speed)
{
	target = NormalizeAngle(target);
	value = NormalizeAngle(value);
	local delta = NormalizeAngle(target - value);
	if (delta > speed)
		return value + speed;
	else if (delta < -speed)
		return value - speed;
	return value;
}

// Converts a vector direction into angles
function VectorAngles(forward)
{
	local yaw, pitch;
	if ( forward.y == 0.0 && forward.x == 0.0 )
	{
		yaw = 0.0;
		if (forward.z > 0.0)
			pitch = 270.0;
		else
			pitch = 90.0;
	}
	else
	{
		yaw = (atan2(forward.y, forward.x) * 180.0 / Constants.Math.Pi);
		if (yaw < 0.0)
			yaw += 360.0;
		pitch = (atan2(-forward.z, forward.Length2D()) * 180.0 / Constants.Math.Pi);
		if (pitch < 0.0)
			pitch += 360.0;
	}

	return QAngle(pitch, yaw, 0.0);
}

// Coordinate which is part of a path
class PathPoint
{
	constructor(_area, _pos, _how)
	{
		area = _area;
		pos = _pos;
		how = _how;
	}

	area = null;	// Which area does this point belong to?
	pos = null;		// Coordinates of the point
	how = null;		// Type of traversal. See Constants.ENavTraverseType
}

// The big boy that handles all our behavior
class Bot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 230.0;
		turn_rate = 5.0;
		search_dist_z = 128.0;
		search_dist_nearest = 128.0;

		path = [];
		path_index = 0;
		path_reach_dist = 16.0;
		path_target_ent = null;
		path_target_ent_dist = 50.0;
		path_target_pos = null;
		path_update_time_next = Time();
		path_update_time_delay = 0.2;
		path_update_force = true;
		area_list = {};

		seq_idle = bot_ent.LookupSequence("Stand_MELEE");
		seq_run = bot_ent.LookupSequence("Run_MELEE");
		pose_move_x = bot_ent.LookupPoseParameter("move_x");

		debug = false;

		bIsOnFire = false;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");
	}

	function Precache()
	{
		bot.PrecacheScriptSound( "TFPlayer.CritHit" );
		bot.PrecacheScriptSound( "TFPlayer.CritHitMini" );
	}

	function Spawn()
	{
		Precache();

		bot.AddFlag(Constants.FPlayer.FL_NPC);
		NetProps.SetPropBool( bot, "m_bResolvePlayerCollisions", false );
	}

	function AlertSound()
	{
	}

	function UpdatePath()
	{
		// Clear out the path first
		ResetPath();

		// If there is a follow entity specified, then the bot will pathfind to the entity
		if ( path_target_ent != null )
		{
			path_target_pos = path_target_ent.GetOrigin();
		}
		else
		{
			path_target_pos = bot.GetOrigin();
			path_target_ent = null;
			return false;
		}

		// Pathfind from the bot's position to the target position
		local pos_start = bot.GetLocomotionInterface().GetFeet();
		local pos_end = path_target_pos;

		local area_start = NavMesh.GetNavArea(pos_start, search_dist_z);
		local area_end = NavMesh.GetNavArea(pos_end, search_dist_z);

		// If either area was not found, try use the closest one
		if (area_start == null)
			area_start = NavMesh.GetNearestNavArea(pos_start, search_dist_nearest, false, true);
		if (area_end == null)
			area_end = NavMesh.GetNearestNavArea(pos_end, search_dist_nearest, false, true);

		// If either area is still missing, then bot can't progress
		if (area_start == null || area_end == null)
			return false;

		// If the start and end area is the same, one path point is enough and all the expensive path building can be skipped
		if (area_start == area_end)
		{
			path.append(PathPoint(area_end, pos_end, Constants.ENavTraverseType.NUM_TRAVERSE_TYPES));
			return true;
		}

		// Build list of areas required to get from the start to the end
		if (!NavMesh.GetNavAreasFromBuildPath(area_start, area_end, pos_end, 0.0, Constants.ETFTeam.TEAM_ANY, false, area_list))
			return false;

		// No areas found? Uh oh
		if (area_list.len() == 0)
			return false;

		// Now build points using the list of areas, which the bot will then follow
		local area_target = area_list["area0"];
		local area = area_target;
		local area_count = area_list.len();

		// Iterate through the list of areas in order and initialize points
		for (local i = 0; i < area_count && area != null; i++)
		{
			path.append(PathPoint(area, area.GetCenter(), area.GetParentHow()));
			area = area.GetParent(); // Advances to the next connected area
		}

		// Reverse the list of path points as the area list is connected backwards
		path.reverse();

		// Now compute accurate path points, using adjacent points + direction data from nav
		local path_first = path[0];
		local path_count = path.len();

		// First point is simply our current position
		path_first.pos = bot.GetLocomotionInterface().GetFeet();
		path_first.how = Constants.ENavTraverseType.NUM_TRAVERSE_TYPES; // No direction specified

		for (local i = 1; i < path_count; i++)
		{
			local path_from = path[i - 1];
			local path_to = path[i];

			// Computes closest point within the "portal" between adjacent areas
			path_to.pos = path_from.area.ComputeClosestPointInPortal(path_to.area, path_to.how, path_from.pos);
		}

		// Add a final point so the bot can precisely move towards the end point when it reaches the final area
		path.append(PathPoint(area_end, pos_end, Constants.ENavTraverseType.NUM_TRAVERSE_TYPES));
	}

	function AdvancePath()
	{
		// Check for valid path first
		local path_len = path.len();
		if (path_len == 0)
			return false;

		local path_pos = path[path_index].pos;
		local bot_pos = bot.GetLocomotionInterface().GetFeet();

		// Are we close enough to the path point to consider it as 'reached'?
		if ((path_pos - bot_pos).Length2D() < path_reach_dist)
		{
			// Start moving to the next point
			path_index++;
			if (path_index >= path_len)
			{
				// End of the line!
				ResetPath();
				return false;
			}
		}

		if ( !bot.GetLocomotionInterface().IsOnGround() )
			return false;

		return true;
	}

	function ResetPath()
	{
		area_list.clear();
		path.clear();
		path_index = 0;
	}

	function Move()
	{
		// Recompute the path if forced to do so
		if (path_update_force)
		{
			UpdatePath();
			path_update_force = false;
		}
		// Recompute path to our target if present
		else if (path_target_ent && path_target_ent.IsValid())
		{
			// Is it time to re-compute the path?
			local time = Time();
			if (path_update_time_next < time)
			{
				// Check if target has moved far away enough
				if ((path_target_pos - path_target_ent.GetOrigin()).Length() > path_target_ent_dist)
				{
					UpdatePath();
					// Don't recompute again for a moment
					path_update_time_next = time + path_update_time_delay;
				}
			}
		}

		// Check and advance up our path
		if (AdvancePath())
		{
			local path_pos = path[path_index].pos;
			local bot_pos = bot.GetLocomotionInterface().GetFeet();

			// Direction towards path point
			local move_dir = (path_pos - bot_pos);
			move_dir.Norm();

			// Convert direction into angle form
			local move_ang = VectorAngles(move_dir);

			// Approach new desired angle but only on the Y axis
			local bot_ang = bot.GetAbsAngles()
			move_ang.x = bot_ang.x;
			move_ang.y = ApproachAngle(move_ang.y, bot_ang.y, turn_rate);
			move_ang.z = bot_ang.z;

			// Set our new position and angles
			// Velocity is calculated from direction times speed, and converted from per-second to per-tick time
			//bot.GetLocomotionInterface().SetDesiredSpeed( move_speed );
			//bot.GetLocomotionInterface().Approach(bot_pos + move_dir * move_speed, 1.0);
			bot.SetAbsOrigin(bot_pos + (move_dir * move_speed * FrameTime()));
			bot.SetAbsAngles(move_ang);

			return true;
		}

		return false;
	}

	function SelectVictim()
	{
		if ( IsPotentiallyChaseable( path_target_ent ) )
			return;

		path_target_ent = null;
		local newTarget = Entities.FindByClassnameNearest( "player", bot.GetOrigin(), selectvictim_range );
		if ( newTarget != null )
		{
			if ( IsPotentiallyChaseable( newTarget ) )
			{
				path_target_ent = newTarget;
				AlertSound();
				UpdatePath();
			}
		}
	}

	function IsPotentiallyChaseable(victim)
	{
		if ( victim == null )
			return false;

		if ( NetProps.GetPropInt(victim, "m_lifeState") != 0 ) // 0-LIFE_ALIVE  1-LIFE_DYING
			return false;

		if ( victim.GetHealth() <= 0 )
			return false;

		if ( victim.GetTeam() == bot.GetTeam() )
			return false;

		if ((bot.GetOrigin() - victim.GetOrigin()).Length() > 2000.0)
			return false;

		if ( victim.IsPlayer() )
		{
			if ( victim.IsFullyInvisible() )
				return false;

			if ( victim.IsInvulnerable() )
				return false;

			//if ( !( victim.GetFlags() & Constants.FPlayer.FL_ONGROUND ) )
			//{
			//	Vector victimAreaPos;
			//	victimArea->GetClosestPointOnArea( victim->GetAbsOrigin(), &victimAreaPos );
			//	if ( ( victim->GetAbsOrigin() - victimAreaPos ).AsVector2D().IsLengthGreaterThan( 50.0f ) )
			//	{
			//		// off the mesh and unreachable - pick a new victim
			//		return false;
			//	}
			//}

			if ( victim.InAirDueToExplosion() )
				return false;

			if ( victim.InCond(Constants.ETFCond.TF_COND_HALLOWEEN_GHOST_MODE) )
				return false;

			if ( victim.GetLastKnownArea() && ( victim.GetLastKnownArea() instanceof CTFNavArea ) )
			{
				if ( victim.GetLastKnownArea().HasAttributeTF( Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_BLUE | Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_RED ) )
					return false;

				if ( victim.GetLastKnownArea().IsPotentiallyVisibleToTeam( bot.GetTeam() ) )
					return true;

				if ( victim.GetLastKnownArea().IsReachableByTeam( bot.GetTeam() ) )
					return true;
			}
		}

		return true;
	}

	function IsPotentiallyVisible(victim)
	{
		if ( victim == null )
			return false;

		if ( NetProps.GetPropInt(victim, "m_lifeState") != 0 ) // 0-LIFE_ALIVE  1-LIFE_DYING
			return false;

		if ( victim.GetHealth() <= 0 )
			return false;

		if ( victim.GetTeam() == bot.GetTeam() )
			return false;

		if ( victim.IsPlayer() )
		{
			if ( victim.IsFullyInvisible() )
				return false;

			if ( victim.IsInvulnerable() )
				return false;

			if ( victim.InCond(Constants.ETFCond.TF_COND_HALLOWEEN_GHOST_MODE) )
				return false;

			if ( victim.GetLastKnownArea() && ( victim.GetLastKnownArea() instanceof CTFNavArea ) )
			{
				if ( victim.GetLastKnownArea().HasAttributeTF( Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_BLUE | Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_RED ) )
					return false;

				if ( victim.GetLastKnownArea().IsCompletelyVisibleToTeam( bot.GetTeam() ) )
					return false;
			}
		}

		return true;
	}

	function Update()
	{
		SelectVictim();

		// Try moving
		if (Move())
		{
			// Moving, set the run animation
			if (bot.GetSequence() != seq_run)
			{
				bot.SetSequence(seq_run);
				bot.SetPoseParameter(pose_move_x, 1.0); // Set the move_x pose to max weight
			}
		}
		else
		{
			// Not moving, set the idle animation
			if (bot.GetSequence() != seq_idle)
			{
				bot.SetSequence(seq_idle);
				bot.SetPoseParameter(pose_move_x, 0.0); // Clear the move_x pose
			}
		}

		// adjust animation speed to actual movement speed
		if ( bot.GetLocomotionInterface().GetGroundSpeed() > 0.0 )
		{
			// Clamp playback rate to avoid datatable warnings.  Anything faster would look silly, anyway.
			local playbackRate = clamp( speed / bot.GetLocomotionInterface().GetGroundSpeed(), -4.0, 12.0 );
			bot.SetPlaybackRate( playbackRate );
		}

		// Replay animation if it has finished
		if (bot.GetCycle() > 0.99)
			bot.SetCycle(0.0);

		// Run animations
		bot.StudioFrameAdvance();
		bot.DispatchAnimEvents(bot);

		// Visualize current path in debug mode
		if (debug)
		{
			// Stay around for 1 tick
			// Debugoverlays are created on 1st tick but start rendering on 2nd tick, hence this must be doubled
			local frame_time = FrameTime() * 2.0;

			// Draw connected path points
			local path_len = path.len();
			if (path_len > 0)
			{
				local path_start_index = path_index;
				if (path_start_index == 0)
					path_start_index++;

				for (local i = path_start_index; i < path_len; i++)
				{
					DebugDrawLine(path[i - 1].pos, path[i].pos, 0, 255, 0, true, frame_time);
				}
			}

			// Draw areas from built path
			foreach (name, area in area_list)
			{
				area.DebugDrawFilled(255, 0, 0, 30, frame_time, true, 0.0);
				DebugDrawText(area.GetCenter(), name, false, frame_time);
			}
		}

		return bot.GetTickLastUpdate(); // Think again next frame
	}

	function Ignite()
	{
		bIsOnFire = true;
		//EntFireByHandle( bot, "Ignite", "", 0, null, null );
	}

	function OnTakeDamage(params)
	{
		damage_force = params.damage_force;

		if ( params.damage_type & Constants.FDmgType.DMG_BURN 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING_FLARE 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_FLYINGBURN 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BURNING_ARROW 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_FLARE_EXPLOSION 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_PLASMA_CHARGED 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_FLARE_PELLET 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SPELL_FIREBALL 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SPELL_METEOR 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DRAGONS_FURY_IGNITE 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DRAGONS_FURY_BONUS_BURNING )
		{
			if ( !bIsOnFire )
				Ignite();
		}

		local weapon = params.weapon;
		if ( weapon && weapon.IsValid() )
		{
			if ( ( params.attacker && params.attacker.IsCritBoosted() ) || ( NetProps.GetPropBool(weapon, "m_bCurrentAttackIsCrit") == true ) || params.crit_type == Constants.ECritType.CRIT_FULL 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_CLEAVER_CRIT
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SHOTGUN_REVENGE_CRIT )
			{
				DispatchParticleEffect( "crit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("headcrab")), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHit", 10.0, 75, 100, bot );
			}

			if ( params.crit_type == Constants.ECritType.CRIT_MINI )
			{
				DispatchParticleEffect( "minicrit_text", bot.GetOrigin(), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHitMini", 10.0, 75, 100, bot );
			}
		}

	}

	function OnKilled(params)
	{
		NetProps.SetPropInt(bot, "m_lifeState", 1);
		bot.SetHealth(bot.GetMaxHealth() * 20);

		AddThinkToEnt(bot, null);
		bot.TerminateScriptScope();

		bot.Kill();
	}

	bot = null;						// The bot entity we belong to

	move_speed = null;				// How fast to move
	turn_rate = null;				// How fast to turn
	search_dist_z = null;			// Maximum distance to look for a nav area downwards
	search_dist_nearest = null; 	// Maximum distance to look for any nearby nav area

	path = null;					// List of BotPathPoints
	path_index = null;				// Current path point bot is at, -1 if none
	path_reach_dist = null;			// Distance to a path point to be considered as 'reached'
	path_target_ent = null;			// What entity to move towards
	path_target_ent_dist = null;	// Maximum distance after which the path is recomputed
									// if follow entity's current position is too far from our target position
	path_target_pos = null;			// Position where bot wants to navigate to
	path_update_time_next = null;	// Timer for when to update path again
	path_update_time_delay = null;  // Seconds to wait before trying to attempt to update path again
	path_update_force = null;		// Force path recomputation on the next tick
	area_list = null;				// List of areas built in path

	seq_idle = null;				// Animation to use when idle
	seq_run = null;					// Animation to use when running
	seq_attack = null;
	pose_move_x = null;				// Pose parameter to set for running animation

	damage_force = null;			// Damage force from the bot's last OnTakeDamage event

	debug = false;					// When true, debug visualization is enabled

	selectvictim_range = 500.0;
	quitvictim_range = 1000.0;

	bIsOnFire = false;
}

function BotThink()
{
	// Let the bot class handle all the work
	return self.GetScriptScope().my_bot.Update();
}

::BotCreate <- function()
{
	// Find point where player is looking
	local player = GetListenServerHost();
	local trace =
	{
		start = player.EyePosition(),
		end = player.EyePosition() + (player.EyeAngles().Forward() * 32768.0),
		ignore = player
	};

	if (!TraceLineEx(trace))
	{
		printl("Invalid bot spawn location");
		return null;
	}

	// Spawn bot at the end point
	local bot = SpawnEntityFromTable("base_boss",
	{
		targetname = "bot",
		origin = trace.pos,
		model = "models/bots/heavy/bot_heavy.mdl",
		playbackrate = 1.0, // Required for animations to be simulated
		health = 100
	});

	// Add scope to the entity
	bot.ValidateScriptScope();
	// Append custom bot class and initialize its behavior
	bot.GetScriptScope().my_bot <- Bot(bot);

	return bot;
}

function OnScriptHook_OnTakeDamage(params)
{
	local ent = params.const_entity;
	local inf = params.inflictor;
	if ( ent == null )
		return;

	if (ent.GetClassname() == "base_boss" && HasBotScript(ent))
	{
		// Save the damage force into the bot's data
		ent.GetScriptScope().my_bot.OnTakeDamage(params);
	}
}

function OnGameEvent_npc_hurt(params)
{
	local ent = EntIndexToHScript( params.entindex );
	if ( ent && ent.IsValid() )
	{
		// Check if a bot is about to die
		if ( HasBotScript(ent) && ((ent.GetHealth() - params.damageamount) <= 0))
		{
			// Run the bot's OnKilled function
			ent.GetScriptScope().my_bot.OnKilled(params);
		}
	}
}
__CollectGameEventCallbacks(this);

function HasBotScript(ent)
{
	// Return true if this entity has the my_bot script scope
	return (ent.GetScriptScope() != null && ent.GetScriptScope().my_bot != null);
}

//BotCreate();