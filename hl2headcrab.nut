//================================================
// recreation of Half-Life 2 npc_headcrab 
//================================================
IncludeScript("puddybot/botbase.nut");

local HEADCRAB_MELEE_REACH = 55;
local HEADCRAB_HEALTH = 50;

local HEADCRAB_ATTACK_SOUND =
[
	"npc/headcrab/attack1.wav",
	"npc/headcrab/attack2.wav",
	"npc/headcrab/attack3.wav",
];

const HEADCRAB_BITE_SOUND = "npc/headcrab/headbite.wav";

local HEADCRAB_DEATH_SOUND =
[
	"npc/headcrab/die1.wav",
	"npc/headcrab/die2.wav",
];

local HEADCRAB_ALERT_SOUND =
[
	"npc/headcrab/alert1.wav",
];

local HEADCRAB_PAIN_SOUND =
[
	"npc/headcrab/pain1.wav",
	"npc/headcrab/pain2.wav",
	"npc/headcrab/pain3.wav",
];

local HEADCRAB_IDLE_SOUND =
[
	"npc/headcrab/idle1.wav",
	"npc/headcrab/idle2.wav",
	"npc/headcrab/idle3.wav",
];



class CHeadcrab extends PuddyBot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 50.0;
		turn_rate = 5.0;
		search_dist_z = 128.0;
		search_dist_nearest = 128.0;

		path = [];
		path_index = 0;
		path_reach_dist = 50.0;
		path_target_ent = null;
		path_target_ent_dist = 150.0;
		path_target_pos = null;
		path_update_time_next = Time();
		path_update_time_delay = 0.2;
		path_update_force = true;
		area_list = {};

		attack_update_time_next = Time();

		seq_idle = bot_ent.LookupSequence("Idle01");
		seq_run = bot_ent.LookupSequence("Run1");
		seq_attack = bot_ent.LookupSequence("jumpattack_broadcast");
		pose_move_x = bot_ent.LookupPoseParameter("move_x");

		debug = false;
		bIsOnFire = false;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");		
	}

	function Precache()
	{
		PrecacheModel( "models/headcrabclassic.mdl" );

		PrecacheSound( HEADCRAB_BITE_SOUND );

		for (local i = 0; i < HEADCRAB_ATTACK_SOUND.len(); i++)
		{
				PrecacheSound( HEADCRAB_ATTACK_SOUND[i] );
		}

		for (local i = 0; i < HEADCRAB_DEATH_SOUND.len(); i++)
		{
				PrecacheSound( HEADCRAB_DEATH_SOUND[i] );
		}

		for (local i = 0; i < HEADCRAB_ALERT_SOUND.len(); i++)
		{
				PrecacheSound( HEADCRAB_ALERT_SOUND[i] );
		}

		for (local i = 0; i < HEADCRAB_PAIN_SOUND.len(); i++)
		{
				PrecacheSound( HEADCRAB_PAIN_SOUND[i] );
		}

		for (local i = 0; i < HEADCRAB_IDLE_SOUND.len(); i++)
		{
				PrecacheSound( HEADCRAB_IDLE_SOUND[i] );
		}
	}

	function Spawn()
	{
		base.Spawn();

		bot.SetHealth(HEADCRAB_HEALTH);
		bot.SetMaxHealth(HEADCRAB_HEALTH);

		bot.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER);
	}

	function JumpAttack()
	{
		local time = Time();
		if (attack_update_time_next < time)
		{
			local bot_pos = bot.GetOrigin();
			local playerTarget = Entities.FindInSphere( null, bot_pos, HEADCRAB_MELEE_REACH );
			if (path_target_ent && path_target_ent.IsValid())
			{
				if ( playerTarget && playerTarget.IsValid() && playerTarget == path_target_ent && playerTarget.GetHealth() > 0 )
				{
					local trace =
					{
						start = bot_pos,
						end = bot_pos + (bot.GetAbsAngles().Forward() * HEADCRAB_MELEE_REACH),
						ignore = bot
					};

					if (TraceLineEx(trace) && ( ("enthit" in trace) && ( trace.enthit == playerTarget ) ) )
					{
						bot.GetLocomotionInterface().Jump();
						bot.GetLocomotionInterface().JumpAcrossGap(playerTarget.GetOrigin(),playerTarget.EyeAngles().Forward());
						bot.SetAbsVelocity( bot.GetOrigin() - playerTarget.EyePosition() );

						EmitAmbientSoundOn( HEADCRAB_ATTACK_SOUND[rand() % HEADCRAB_ATTACK_SOUND.len()], 10.0, 75, 100, bot );
								
						local vDmgForce = bot_pos - playerTarget.GetOrigin();

						playerTarget.TakeDamageCustom(bot,bot,bot,vDmgForce,trace.pos,20,Constants.FDmgType.DMG_SLASH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_SPELL_SKELETON);
						playerTarget.ApplyAbsVelocityImpulse(vDmgForce*-HEADCRAB_MELEE_REACH);
						EmitAmbientSoundOn( HEADCRAB_BITE_SOUND, 5.0, 50, 100, playerTarget );

						attack_update_time_next = time + bot.GetSequenceDuration(seq_attack);
						ResetPath();
						path_update_time_next = time + bot.GetSequenceDuration(seq_attack);
						return true;
					}
				}
			}
		}

		return false;
	}

	function Update()
	{
		SelectVictim();

		if (JumpAttack())
		{
			if (bot.GetSequence() != seq_attack)
			{
				bot.SetSequence(seq_attack);
				bot.SetPoseParameter(pose_move_x, 0.0);
			}
		}
		else
		{
			if (Move()) // Try moving
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
		}

		// Replay animation if it has finished
		if (bot.GetCycle() > 0.99)
			bot.SetCycle(0.0);

		// Run animations
		bot.StudioFrameAdvance();
		bot.DispatchAnimEvents(bot);

		return 0.0; // Think again next frame
	}

	function OnTakeDamage(params)
	{
		EmitAmbientSoundOn( HEADCRAB_PAIN_SOUND[rand() % HEADCRAB_PAIN_SOUND.len()], 10.0, 75, 100, bot );

		DispatchParticleEffect( "spell_skeleton_goop_green", params.damage_position, Vector(0,0,0) );

		base.OnTakeDamage(params);
	}

	function OnKilled(params)
	{
		EmitAmbientSoundOn( HEADCRAB_DEATH_SOUND[rand() % HEADCRAB_DEATH_SOUND.len()], 10.0, 75, 100, bot );

		base.OnKilled(params);
	}

	attack_update_time_next = null;
}

::SpawnHeadcrab <- function()
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
		targetname = "npc_headcrab",
		origin = trace.pos,
		model = "models/headcrabclassic.mdl",
		playbackrate = 1.0
	});
	
	// Add scope to the entity
	bot.ValidateScriptScope();
	// Append custom bot class and initialize its behavior
	bot.GetScriptScope().my_bot <- CHeadcrab(bot);

	return bot;
}
