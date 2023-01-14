//================================================
// "Mecha Level 4 Sentry" Boss from Raid Mode
//================================================
DoIncludeScript("puddybot/botbase.nut", null);

const tf_bot_npc_health = 100000;

const tf_bot_npc_speed = 300;
const tf_bot_npc_attack_range = 300;

const tf_bot_npc_melee_damage = 150;

const tf_bot_npc_threat_tolerance = 100;

const tf_bot_npc_shoot_interval = 15;
const tf_bot_npc_aim_time = 1;

const tf_bot_npc_chase_range = 300;

const tf_bot_npc_grenade_launch_range = 300;
const tf_bot_npc_grenade_damage = 25;

const tf_bot_npc_minion_launch_count_initial = 5;
const tf_bot_npc_minion_launch_count_increase_interval = 999999999;
const tf_bot_npc_minion_launch_initial_interval = 20;
const tf_bot_npc_minion_launch_interval = 30;

const tf_bot_npc_chase_duration = 30;
const tf_bot_npc_quit_range = 2500;

const tf_bot_npc_reaction_time = 0.5;

const tf_bot_npc_charge_interval = 10;
const tf_bot_npc_charge_pushaway_force = 500;
const tf_bot_npc_charge_damage = 150;

const tf_bot_npc_nuke_charge_time = 5;
const tf_bot_npc_nuke_interval = 20;
const tf_bot_npc_nuke_lethal_time = 999999999;

const tf_bot_npc_block_dps_react = 150;

const tf_bot_npc_become_stunned_damage = 500;
const tf_bot_npc_stunned_injury_multiplier = 10.0;
const tf_bot_npc_stunned_duration = 5;
const tf_bot_npc_head_radius = 100; // 75;

const tf_bot_npc_stun_rocket_reflect_count = 2;
const tf_bot_npc_stun_rocket_reflect_duration = 1;

const tf_bot_npc_grenade_interval = 10;

const tf_bot_npc_hate_taunt_cooldown = 10;

const tf_bot_npc_debug_damage = 0;

const tf_bot_npc_always_stun = 0;
const tf_bot_npc_min_nuke_after_stun_time = 5;

const tf_bot_npc_nuke_damage = 75;
const tf_bot_npc_nuke_max_remaining_health = 60;
const tf_bot_npc_nuke_afterburn_time = 5;

const tf_bot_npc_grenade_ring_min_horiz_vel = 100;
const tf_bot_npc_grenade_ring_max_horiz_vel = 350;
const tf_bot_npc_grenade_vert_vel = 750;
const tf_bot_npc_grenade_det_time = 3;

	enum Condition
	{
		SHIELDED,
		CHARGING,
		STUNNED,
		INVULNERABLE,
		VULNERABLE_TO_STUN,
		BUSY,
		ENRAGED
	};

class MechaSentry extends PuddyBot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 420.0;
		turn_rate = 10.0;

		seq_idle = bot_ent.LookupSequence( "test" );
		seq_run = bot_ent.LookupSequence( "test" );
		pose_move_x = bot_ent.LookupPoseParameter( "move_x" );
		seq_attack = bot_ent.LookupSequence( "ref" );
		seq_nuke = bot_ent.LookupSequence( "ref" );
		seq_grabplayer = bot_ent.LookupSequence( "ref" );
		seq_stun = bot_ent.LookupSequence( "ref" );

		//selectvictim_range = FLT_MAX;
		quitvictim_range = 1500.0;

		home_pos = null;

		m_conditionFlags.clear();
		/*m_laserTarget = null;
		m_isNuking = false;
		m_ageTimer.Invalidate();
		m_spawner = null;*/
		m_stunDamage = 0.0;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");		
	}

	function Precache()
	{
		//PrecacheModel( "models/bots/boss_sentry/boss_sentry.mdl" );
		PrecacheModel( "models/bots/boss_bot/boss_bot.mdl" );

		PrecacheScriptSound( "Weapon_Sword.Swing" );
		PrecacheScriptSound( "Weapon_Sword.HitFlesh" );
		PrecacheScriptSound( "Weapon_Sword.HitWorld" );
		PrecacheScriptSound( "DemoCharge.HitWorld" );
		PrecacheScriptSound( "TFPlayer.Pain" );
		PrecacheScriptSound( "Halloween.HeadlessBossAttack" );
		/*PrecacheScriptSound( "RobotBoss.StunStart" );
		PrecacheScriptSound( "RobotBoss.Stunned" );
		PrecacheScriptSound( "RobotBoss.StunRecover" );
		PrecacheScriptSound( "RobotBoss.Acquire" );
		PrecacheScriptSound( "RobotBoss.Vocalize" );
		PrecacheScriptSound( "RobotBoss.Footstep" );
		PrecacheScriptSound( "RobotBoss.LaunchGrenades" );
		PrecacheScriptSound( "RobotBoss.LaunchRockets" );
		PrecacheScriptSound( "RobotBoss.Hurt" );
		PrecacheScriptSound( "RobotBoss.Vulnerable" );
		PrecacheScriptSound( "RobotBoss.ChargeUpNukeAttack" );
		PrecacheScriptSound( "RobotBoss.NukeAttack" );
		PrecacheScriptSound( "RobotBoss.Scanning" );
		PrecacheScriptSound( "RobotBoss.ReinforcementsArrived" );*/

		PrecacheScriptSound( "Cart.Explode" );

		PrecacheScriptSound( "TFPlayer.StunImpact" );
		PrecacheScriptSound( "Halloween.Merasmus_Stun" );
		PrecacheScriptSound( "Weapon_StickyBombLauncher.ChargeUp" );
		PrecacheScriptSound( "Building_Sentrygun.Idle" );
		PrecacheScriptSound( "Building_Sentry.Damage" );
		PrecacheScriptSound( "doomsday.launch_exp" );

		//PrecacheParticleSystem( "asplode_hoodoo_embers" );
		//PrecacheParticleSystem( "charge_up" );

		//PrecacheArmorParts();
	}

	function Spawn()
	{
		base.Spawn();

		local bossHealth = tf_bot_npc_health;
		bot.SetHealth(bossHealth);
		bot.SetMaxHealth(bossHealth);

		bot.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER);

		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 255.0 * 1 );
		}

		bot.AddSolidFlags(Constants.FSolid.FSOLID_NOT_STANDABLE );

		home_pos = bot.GetOrigin();

		SendGlobalGameEvent( "teamplay_broadcast_audio", {team = -1, sound = "Taunt.YetiAppearSnow"} );
		//DispatchParticleEffect( "teleported_mvm_bot", bot.GetOrigin() + Vector(0,0,50), Vector(0,0,0) );
		DispatchParticleEffect( "taunt_yeti_flash", bot.GetOrigin(), Vector(0,0,0) );

		//Say(null,"MECHA SENTRY (LEVEL 4) has been activated!\n", false);

		SendGlobalGameEvent( "player_connect_client", {name = "MECHA SENTRY (LEVEL 4)"} );
	}

	function AlertSound()
	{
		//EmitSoundEx({sound_name = "Building_Sentrygun.Alert", channel = 2, volume = 1.0, flags = 0, entity = bot });
		EmitAmbientSoundOn( "Building_Sentrygun.Alert", 10.0, 75, 100, bot );
	}

	function IsPotentiallyChaseable(victim)
	{
		if ( victim == null )
			return false;

		if ( !IsAlive( victim ) ) 
			return false;

		if ( victim.GetHealth() == 0 )
			return false;

		if ( victim.GetTeam() == bot.GetTeam() )
			return false;

		if ((bot.GetOrigin() - victim.GetOrigin()).Length() > quitvictim_range)
			return false;

		if ( victim.IsPlayer() )
		{
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
		}

		if ( victim.GetLastKnownArea() && ( victim.GetLastKnownArea() instanceof CTFNavArea ) )
		{
			if ( victim.GetLastKnownArea().HasAttributeTF( Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_BLUE | Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_RED ) )
				return false;

			if ( victim.GetLastKnownArea().IsPotentiallyVisibleToTeam( bot.GetTeam() ) )
				return true;

			if ( victim.GetLastKnownArea().IsReachableByTeam( bot.GetTeam() ) )
				return true;
		}

		return true;
	}

	function UpdateAttack()
	{
		if ( IsStunned() )
			return;

		if ( !m_nukeTimer.Running() )
			m_nukeTimer.Start( tf_bot_npc_nuke_interval );

		if ( attack_timer.IsElapsed() )
		{
			if (path_target_ent && path_target_ent.IsValid())
			{
				if ((path_target_ent.GetOrigin() - bot.GetOrigin()).Length2D() < tf_bot_npc_attack_range)
				{
					bot.GetLocomotionInterface().Stop();
					FaceTowards( path_target_ent.GetOrigin() );

					if ( m_nukeTimer.IsElapsed() )
					{
						m_nukeTimer.Stop();
						local grabbableTarget = Entities.FindByClassnameNearest( "player", bot.GetOrigin(), 128.0 );
						if ( debug )
							DebugDrawCircle(bot.GetOrigin(), 0, 255, 0, 128.0, true, 5);

						attack_nuke_hit_timer.Start( tf_bot_npc_nuke_charge_time );
						attack_timer.Start( 7 );
						AddCondition( Condition.VULNERABLE_TO_STUN );

						EmitAmbientSoundOn( "Weapon_StickyBombLauncher.ChargeUp", 10.0, 100, 2500, bot );

						DispatchParticleEffect( "charge_up", bot.GetAttachmentOrigin( bot.LookupAttachment( "head" ) ), Vector(0,0,0) );
						ScreenShake( bot.GetOrigin(), 15.0, 5.0, 1.0, 3000.0, 0, false );

						bot.ResetSequence(seq_nuke);
						if (bot.GetSequence() != seq_nuke)
							bot.SetSequence(seq_nuke);

						ResetPath();
						path_update_time_next = Time() + 7;
						path_update_force = true;
						return;
					}


					if ( IsInCondition( Condition.ENRAGED ) )
					{
						EmitAmbientSoundOn( "Weapon_RPG.SingleCrit", 10.0, 100, 2500, bot );

						local projectile = Entities.CreateByClassname("tf_projectile_pipe_remote")
						projectile.SetOrigin( bot.GetAttachmentOrigin( bot.LookupAttachment( "hatches" ) ) );
						projectile.SetAbsVelocity( bot.GetAbsVelocity() * tf_bot_npc_grenade_vert_vel );
						projectile.ApplyLocalAngularVelocityImpulse( Vector( 600, RandomInt( -1200, 1200 ), 0 ) );

						NetProps.SetPropInt( projectile, "m_iType", 4 ); // TF_PROJECTILE_PIPEBOMB_REMOTE
						Entities.DispatchSpawn(projectile);
						projectile.SetOwner( bot );
						projectile.SetGravity( 0.4 );
						projectile.SetFriction( 0.2 );
						//projectile.SetElasticity( 0.45 );
						NetProps.SetPropFloat( projectile, "m_flDamage", tf_bot_npc_grenade_damage );
						NetProps.SetPropFloat( projectile, "m_DmgRadius", 150 );
						bot.SetTeam( bot.GetTeam() );
						NetProps.SetPropBool( projectile, "m_bCritical", true );
						RemoveCondition( Condition.ENRAGED );
					}
					else
					{
						EmitSoundEx({sound_name = "Building_Sentrygun.Alert", channel = 2, volume = 1.0, flags = 0, entity = bot});

						bot.ResetSequence(seq_attack);
						if (bot.GetSequence() != seq_attack)
							bot.SetSequence(seq_attack);

						attack_hit_timer.Start( 0.2 );
						attack_timer.Start( 1.2 );

						ResetPath();
						path_update_time_next = Time() + 0.5;
						path_update_force = true;
					}
				}
			}
		}

		if ( attack_hit_timer.Running() )
		{
			if ( attack_hit_timer.IsElapsed() )
			{
				MeleeAttack();
			}
		}

		if ( attack_nuke_hit_timer.Running() )
		{
			if ( attack_nuke_hit_timer.IsElapsed() )
			{
				NukeAttack();
			}
		}
	}

	function MeleeAttack()
	{
		attack_hit_timer.Stop();

		local bot_pos = bot.EyePosition();
		if (path_target_ent && path_target_ent.IsValid())
		{
			local trace =
			{
				start = bot_pos,
				end = bot_pos + (bot.GetAbsAngles().Forward() * tf_bot_npc_attack_range),
				hullmin = Vector(-16,-16,-32),
				hullmax = Vector(16,16,32),
				mask = Constants.FContents.CONTENTS_SOLID | Constants.FContents.CONTENTS_MOVEABLE | Constants.FContents.CONTENTS_MONSTER | Constants.FContents.CONTENTS_WINDOW | Constants.FContents.CONTENTS_DEBRIS| Constants.FContents.CONTENTS_GRATE, // MASK_SHOT_HULL
				ignore = bot
			};

			if ( debug )
				DebugDrawLine(bot_pos, bot_pos + (bot.GetAbsAngles().Forward() * tf_bot_npc_attack_range), 0, 255, 0, true, 5);

			if ( TraceHull(trace) && ( ("enthit" in trace) && ( trace.enthit == path_target_ent ) ) )
			{
				local vDmgForce = path_target_ent.GetOrigin() - bot_pos;

				path_target_ent.ApplyPunchImpulseX(4);
				path_target_ent.ApplyAbsVelocityImpulse( vDmgForce * 40 + Vector(0, 0, 200));
				path_target_ent.TakeDamageCustom(bot,bot,bot,vDmgForce,trace.pos, tf_bot_npc_melee_damage,Constants.FDmgType.DMG_CRUSH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS);
				//EmitSoundEx({sound_name = MECHASENTRY_ATTACK_SOUND, volume = 1.0, flags = 0, bot = path_target_ent, origin = path_target_ent.GetOrigin() });
				//EmitAmbientSoundOn( MECHASENTRY_ATTACK_HIT_SOUND, 10.0, 100, 100, path_target_ent );
			}
		}
	}

	function NukeAttack()
	{
		attack_nuke_hit_timer.Stop();
		path_target_ent = null;

		DispatchParticleEffect( "hammer_impact_button", bot.GetOrigin(), Vector(0,0,0) );
		DispatchParticleEffect( "flash_doomsday", bot.GetOrigin(), Vector(0,0,0) );
		EmitAmbientSoundOn( "doomsday.launch_exp", 10.0, 5000, 100, bot );
		ScreenShake(bot.GetOrigin(), 5.0, 5.0, 1.0, 1500.0, 0, false);

		RemoveCondition( Condition.VULNERABLE_TO_STUN );
		m_stunDamage = 0.0; //ClearStunDamage();

		local targetEnemies = null;
		local targetDamage = tf_bot_npc_nuke_damage;

		if ( debug )
			DebugDrawCircle(bot.GetOrigin(), 0, 255, 0, 330.0, true, 5);

		while ( targetEnemies = Entities.FindInSphere( targetEnemies, bot.GetOrigin(), 2500.0 ) )
		{
			local vPush = targetEnemies.GetOrigin() - bot.GetOrigin();
			vPush.z = 0.0;
			vPush.Norm();
			//vPush.z = 268.3281572999747; // causing weird infinite bunny jump???
			targetEnemies.ApplyAbsVelocityImpulse(vPush);

			if ( targetEnemies.GetFlags() & Constants.FPlayer.FL_ONGROUND )
				NetProps.SetPropEntity( targetEnemies, "m_hGroundEntity", null );

			if ( targetEnemies.IsPlayer() )
			{

				if ( tf_bot_npc_nuke_max_remaining_health >= 0.0 )
				{
					// nuke slams everyone's health to this
					if ( targetEnemies.GetHealth() > tf_bot_npc_nuke_max_remaining_health )
					{
						targetDamage = targetEnemies.GetHealth() - tf_bot_npc_nuke_max_remaining_health;
					}
				}

				targetEnemies.ApplyPunchImpulseX(10);
				targetEnemies.IgnitePlayer(); //tf_bot_npc_nuke_afterburn_time
				EntFireByHandle( targetEnemies, "SpeakResponseConcept", "TLK_PLAYER_PAIN", 0, null, null );
				ScreenFade( targetEnemies, 255, 255, 255, 255, 1.0, 0.1, 1 );
			}
			targetEnemies.TakeDamageCustom(bot,bot,bot,vPush,Vector(0, 0, 0),targetDamage,Constants.FDmgType.DMG_ENERGYBEAM, Constants.ETFDmgCustom.TF_DMG_CUSTOM_NONE );
		}
	}

	function RushAttack()
	{
		// pushaway/hit nearby players
		/*CUtlVector< CTFPlayer * > playerVector;
		CollectPlayers( &playerVector, TF_TEAM_RED, COLLECT_ONLY_LIVING_PLAYERS );
		CollectPlayers( &playerVector, TF_TEAM_BLUE, COLLECT_ONLY_LIVING_PLAYERS, APPEND_PLAYERS );

		Vector chargeVector = me->GetAbsOrigin() - m_chargeOrigin;
		chargeVector.NormalizeInPlace();

		const float chargeRadius = 150.0f;

		for( int i=0; i<playerVector.Count(); ++i )
		{
			CTFPlayer *victim = playerVector[i];

			if ( me->IsRangeGreaterThan( victim, chargeRadius ) )
				continue;

			Vector closestPointOnChargePath;
			CalcClosestPointOnLine( victim->GetAbsOrigin(), m_chargeOrigin, me->GetAbsOrigin(), closestPointOnChargePath );

			Vector fromChargePath = victim->GetAbsOrigin() - closestPointOnChargePath;
			float range = fromChargePath.NormalizeInPlace();

			if ( range >= chargeRadius )
				continue;

			if ( !me->IsLineOfSightClear( victim ) )
				continue;

			float nearness = 1.0f - ( range / chargeRadius );

			// push 'em
			float pushForce = tf_bot_npc_charge_pushaway_force.GetFloat() * nearness;
			PushawayPlayer( victim, closestPointOnChargePath, pushForce );

			// crunch 'em
			CTakeDamageInfo info( me, me, tf_bot_npc_charge_damage.GetFloat() * nearness, DMG_CRUSH, TF_DMG_CUSTOM_NONE );

			CalculateMeleeDamageForce( &info, fromChargePath, closestPointOnChargePath, 1.0f );

			victim->TakeDamage( info );

			color32 color = { 255, 0, 0, 255 };
			UTIL_ScreenFade( victim, color, 0.5f, 0.1f, FFADE_IN );

			if ( nearness > 0.5f )
			{
				m_didHitVictim = true;
			}
		}

		float speed = me->GetLocomotionInterface()->GetVelocity().Length();
		m_maxAttainedSpeed = MAX( m_maxAttainedSpeed, speed );

		if ( m_timer.IsElapsed() )
		{
			return ChangeTo( new CBotNPCLaunchRockets, "Finished charge" );
		}
		else
		{
			// chaaarge!
			me->GetLocomotionInterface()->Run();

			Vector forward;
			me->GetVectors( &forward, NULL, NULL );
			me->GetLocomotionInterface()->Approach( 100.0f * forward + me->GetLocomotionInterface()->GetFeet() );

			if ( !m_didHitVictim && m_maxAttainedSpeed > 350.0f && speed - m_lastSpeed < -200.0f )
			{
				// abrupt slowdown = bonk!
				return ChangeTo( new CBotNPCStunned( 3.0f, new CBotNPCLaunchRockets ), "Smacked into the world" );
			}
		}

		// animation
		if ( !me->GetBodyInterface()->IsActivity( ACT_MP_CROUCHWALK_PRIMARY ) )
		{
			me->GetBodyInterface()->StartActivity( ACT_MP_CROUCHWALK_PRIMARY );
		}

		m_lastSpeed = speed;*/
	}

	function HealingSequence()
	{
		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			NetProps.SetPropInt(healthBar, "m_iBossState", 1 );
		}
	}

	function IsAttacking()
	{
		if ( !attack_hit_timer.IsElapsed() )
			return true;

		if ( !attack_nuke_hit_timer.IsElapsed() )
			return true;

		if ( IsStunned() )
			return true;

		return false;
	}

	function CanMove()
	{
		if ( IsAttacking() )
			return false;

		if ( IsStunned() )
			return false;

		if ( IsInCondition( Condition.BUSY ) )
			return false;

		return true;
	}

	function IdleSound()
	{
		local time = Time();
		if (idlevo_time_next < time)
		{
			EmitSoundEx({ sound_name = "Building_Sentrygun.Idle", channel = 2, volume = 1.0, flags = 0, entity = bot });
			ScreenShake(bot.GetOrigin(), 2.0, 2.0, 2.0, 1500.0, 0, false);
			idlevo_time_next = time + RandomFloat( 3.0, 5.0 );
		}
	}

	// look for enemies
	function SelectVictim()
	{
		if ( IsPotentiallyChaseable( path_target_ent ) )
			return;

		path_target_ent = null;

		for ( local i = 1; i <= Constants.Server.MAX_PLAYERS; i++ )
		{
			local player = PlayerInstanceFromIndex(i)
			if ( player == null )
				continue;
	
			if ( !IsPotentiallyChaseable( player ) )
				continue;

			if ( ( player.GetOrigin() - bot.GetOrigin() ).LengthSqr() < FLT_MAX )
			{
				path_target_ent = player;
				AlertSound();
				UpdatePath();

				//if ( GetDeveloperLevel() >= 1 )
					//printl(bot.GetName() + " is chasing " + NetProps.GetPropString(player, "m_szNetname") + "!");
			}
		}
	}

	function Update()
	{
		/*if ( !NetProps.GetPropBool( bot, "m_isEnabled") )
		{
			local healthBar = Entities.FindByClassname(null, "monster_resource");
			if (healthBar && healthBar.IsValid)
			{
				NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
				NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
			}
			return;
		}*/

		if ( stun_timer.Running() )
		{
			if ( stun_timer.IsElapsed() )
			{
				// being stunned makes the boss ANGRY!
				AddCondition( Condition.ENRAGED );
			}
		}

		SelectVictim();

		UpdateAttack();

		// stuck?
		if ( bot.GetLocomotionInterface().IsStuck())
		{
			if ( bot.GetLocomotionInterface().GetStuckDuration() > 5.0 )
			{
				//bot.SetOrigin( bot.GetLastKnownArea().FindRandomSpot() );
				bot.SetOrigin(home_pos);
				bot.GetLocomotionInterface().ClearStuckStatus("MechaSentry goes home.");
				DispatchParticleEffect( "xms_snowburst", bot.GetOrigin() + Vector(0,0,50), Vector(0,0,0) );
			}
		}

		if ( CanMove() )
		{
			if ( Move() )
			{
				// Moving, set the run animation
				if (bot.GetSequence() != seq_run)
				{
					bot.SetSequence(seq_run);
					bot.SetPoseParameter(pose_move_x, 1.0); // Set the move_x pose to max weight
				}
				ScreenShake(bot.GetOrigin(), 1.0, 1.0, 1.0, 500.0, 0, false);
			}
			else
			{
				// Not moving, set the idle animation
				if (bot.GetSequence() != seq_idle)
				{
					bot.SetSequence(seq_idle);
				bot.SetPoseParameter(pose_move_x, 0.0); // Clear the move_x pose
				}
				IdleSound();
			}

			// Replay animation if it has finished
			if (bot.GetCycle() > 0.99)
				bot.SetCycle(0.0);
		}

		if ( IsInCondition( Condition.ENRAGED ) )
		{
			bot.SetPlaybackRate(4.0);
		}
		else
		{
			bot.SetPlaybackRate(1.0);
		}

		// Run animations
		bot.StudioFrameAdvance();
		bot.DispatchAnimEvents(bot);

		return 0.0; // Think again next frame
	}

	function Ignite()
	{
		base.Ignite();
		//DispatchParticleEffect( "mvm_cash_explosion_embers", bot.GetOrigin(), Vector(0,0,0) );
		//EntFireByHandle( bot, "Ignite", "", 0, null, null );=
	}

	function IsStunned()
	{
		if ( IsInCondition( Condition.STUNNED ) )
			return false;

		return !stun_timer.IsElapsed();
	}

	function Stun()
	{
		if ( !stun_timer.IsElapsed() )
			return;

		path_target_ent = null;

		attack_timer.Stop();
		m_nukeTimer.Stop();
		attack_nuke_hit_timer = Timer();

		//AddCondition( Condition.STUNNED );
		DispatchParticleEffect( "bonk_text", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), bot.EyePosition() + Vector(0,0,200) );
		DispatchParticleEffect( "ExplosionCore_sapperdestroyed", bot.GetOrigin(), bot.EyePosition() );
		stun_timer.Start( tf_bot_npc_stunned_duration );
		EmitAmbientSoundOn( "TFPlayer.StunImpact", 10.0, 2000, 100, bot );
		SendGlobalGameEvent( "teamplay_broadcast_audio", {team = -1, sound = "Halloween.Merasmus_Stun"} );
		bot.ResetSequence(seq_stun);
		if (bot.GetSequence() != seq_stun)
			bot.SetSequence(seq_stun);

		RemoveCondition( Condition.VULNERABLE_TO_STUN );

		// throw out some ammo
		/*for( int i=0; i<tf_bot_npc_stun_ammo_count; ++i )
		{
			TossAmmoPack();
		}

		bot.m_outputOnStunned.FireOutput( bot, bot );

		// relay the event to the map logic
		if ( bot.GetSpawner() )
			bot.GetSpawner().OnBotStunned( bot );*/

		ResetPath();
		path_update_time_next = Time() + tf_bot_npc_stunned_duration;
		path_update_force = true;
	}

	function OnTakeDamage(params)
	{
		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			local healthPercentage = params.const_entity.GetHealth().tofloat() / params.const_entity.GetMaxHealth().tofloat();
			if ( healthPercentage <= 0.0 )
			{
				NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
				NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
				return 0;
			}
			else
			{
				NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 255.0 * healthPercentage );
			}
		}

		local stunRatio = m_stunDamage / 500.0; //bot.GetBecomeStunnedDamage();
		if ( /*HasAbility( Ability.CAN_BE_STUNNED ) &&*/ stunRatio >= 1.0 )
		{
			Stun();
		}

		DispatchParticleEffect( "bot_impact_light", params.damage_position, Vector(0,0,0) );
		//EmitSoundEx({sound_name = "TFPlayer.Pain, channel = 6, volume = 1.0, flags = 0, entity = bot});
		EmitAmbientSoundOn( "TFPlayer.Pain", 10.0, 1000, 100, bot );

		damage_force = params.damage_force;

		if ( IsInCondition( Condition.INVULNERABLE ) )
		{
			params.damage = 0;
			return;
		}

		if ( IsInCondition( Condition.SHIELDED ) )
		{
			// no damage from the front
			local inflictor = params.inflictor;
			if ( inflictor )
			{
				if ( DotProduct( inflictor.GetForwardVector(), bot.GetForwardVector() ) < -0.7071 )
				{
					// blocked by my shield
					EmitSound( "FX_RicochetSound.Ricochet" );
					DispatchParticleEffect( "asplode_hoodoo_embers", params.damage_position, Vector(0,0,0) );

					return 0;
				}
			}
		}

		// weapon-specific damage modification
		/*info.SetDamage( ModifyBossDamage( params ) );*/

		if ( IsInCondition( Condition.VULNERABLE_TO_STUN ) )
		{
			if ( true )
			{
				// track head damage when vulnerable
				local headPos = bot.GetAttachmentOrigin( bot.LookupAttachment( "head" ) );
				local headAngles = bot.GetAttachmentAngles( bot.LookupAttachment( "head" ) );

				local damagePos = params.damage_position;

				if ( tf_bot_npc_debug_damage != 0 )
				{
					//NDebugOverlay::Cross3D( headPos, 5.0f, 255, 0, 0, true, 5.0f );
					//NDebugOverlay::Cross3D( damagePos, 5.0f, 0, 255, 0, true, 5.0f );
					DebugDrawLine( damagePos, headPos, 255, 255, 0, true, 5.0 );
				}

				if ( ( damagePos - headPos ).LengthSqr() < tf_bot_npc_head_radius*tf_bot_npc_head_radius )
				{
					// hit the head
					m_stunDamage += params.damage; //AccumulateStunDamage( params.damage );
					//DispatchParticleEffect( "asplode_hoodoo_embers", params.damage_position, Vector(0,0,0) );
					DispatchParticleEffect( "Explosions_MA_Smoke_1", params.damage_position, Vector(0,0,0) );

					if ( tf_bot_npc_debug_damage != 0 )
					{
						printl( "Stun dmg = " + m_stunDamage );
						//DebugDrawCircle( headPos, Vector( 255, 0, 0 ), 255, 0, tf_bot_npc_head_radius, true, 5.0 );
					}
				}
				else if ( tf_bot_npc_debug_damage != 0 )
				{
					//DebugDrawCircle( headPos, Vector( 255, 255, 0 ), 255, 0, tf_bot_npc_head_radius, true, 5.0 );
				}
			}
		}

		if ( IsStunned() )
		{
			params.damage = ( params.damage * tf_bot_npc_stunned_injury_multiplier );

			if ( m_ouchTimer.IsElapsed() )
			{
				m_ouchTimer.Start( 1.0 );
				EmitAmbientSoundOn( "Building_Sentry.Damage", 10.0, 2500, 100, bot );
				//EmitSound( "RobotBoss.Hurt" );
			}
		}

		local weapon = params.weapon;
		if ( weapon && weapon.IsValid() )
		{
			if ( ( params.attacker && params.attacker.IsPlayer() && params.attacker.IsCritBoosted() ) || ( NetProps.GetPropBool(weapon, "m_bCurrentAttackIsCrit") == true ) || params.crit_type == Constants.ECritType.CRIT_FULL 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_CLEAVER_CRIT
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SHOTGUN_REVENGE_CRIT )
			{
				//DispatchParticleEffect( "crit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), bot.EyePosition() + Vector(0,0,50) );
				EmitSoundEx({sound_name = "TFPlayer.CritHit", channel = 3, volume = 0.75, flags = 0, entity = bot });

				if ( IsPotentiallyChaseable( params.attacker ) )
					path_target_ent = params.attacker;
			}
		}

	}

	function OnKilled(params)
	{
		//StopAmbientSoundOn("ui/cyoa_musicdrunkenpipebomb.mp3", bot);
		SendGlobalGameEvent( "teamplay_broadcast_audio", {team = -1, sound = "weapons/sentry_explode.wav"} );
		EmitAmbientSoundOn( "Cart.Explode", 10.0, 5000, 100, bot );

		DispatchParticleEffect( "explosionTrail_seeds_mvm", bot.GetOrigin(), Vector(0,0,0) );
		DispatchParticleEffect( "fluidSmokeExpl_ring_mvm", bot.GetOrigin(), Vector(0,0,0) );

		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
			NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
		}

		//Say(null,"The MECHASENTRY has been defeated!\n", false);
		//SendGlobalGameEvent( "pumpkin_lord_killed", {} );
		SendGlobalGameEvent( "player_disconnect", {name = "MECHA SENTRY (LEVEL 4)", reason = "Defeated by the mercenaries."} );

		base.OnKilled(params);
	}

	function AddCondition( cond )
	{
		m_conditionFlags[cond] <- 1;
	}

	function IsInCondition( cond )
	{
		return ( m_conditionFlags.rawin( cond ) )
	}

	function RemoveCondition( cond )
	{
		if ( cond == Condition.STUNNED )
		{
			// reset the accumulator
			m_stunDamage = 0.0; //ClearStunDamage();
		}

		m_conditionFlags.rawdelete( cond );
	}

	attack_timer = Timer();
	attack_hit_timer = Timer();
	m_nukeTimer = Timer();
	m_grenadeTimer = Timer();
	attack_nuke_hit_timer = Timer();
	m_ouchTimer = Timer();

	idlevo_time_next = null;

	seq_nuke = null;
	seq_grabplayer = null;

	home_pos = null;

	m_stunDamage = 0.0;

	m_conditionFlags = {};
}

function KillMechaSentry()
{
	local bots = null;
	while ( bots = Entities.FindByClassname(bots, "base_boss") )
	{
		if ( HasBotScript( bots ) )
		{
			bots.TakeDamage(bots.GetMaxHealth(),Constants.FDmgType.DMG_CRUSH, null);
			bots.Kill();
		}
	}

	local healthBar = Entities.FindByClassname(null, "monster_resource");
	if (healthBar && healthBar.IsValid)
	{
		NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
		NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
	}
}

::SpawnMechaSentry <- function()
{
	local player = GetListenServerHost();
	local trace =
	{
		start = player.EyePosition(),
		end = player.EyePosition() + (player.EyeAngles().Forward() * 32768.0),
		ignore = player
	};

	if (!TraceLineEx(trace))
	{
		printl("Invalid MECHASENTRY spawn location");
		return null;
	}

	local bot = SpawnEntityFromTable("base_boss", 
	{
		origin = trace.pos,
		model = "models/bots/boss_bot/boss_bot.mdl",
		start_disabled = 0
	});

	EntFireByHandle( bot, "AddOutput", "targetname bot_boss" + bot.GetScriptId(), 0, null, null );

	bot.ValidateScriptScope();
	bot.GetScriptScope().my_bot <- MechaSentry(bot);

	return bot;
}

function OnPostSpawn()
{
	self.ValidateScriptScope();
	self.GetScriptScope().my_bot <- MechaSentry(self);
	//self.ConnectOutput( "OnStunned", "OutputStunned" );
}
