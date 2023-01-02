//================================================
// Shared code for botbase
//================================================

const FLT_EPSILON		= 1.192092896e-7;;
const FLT_MAX			= 3.402823466e+38;;
const FLT_MIN			= 1.175494351e-38;;

const TF_DEATH_DOMINATION	=			1	// killer is dominating victim
const TF_DEATH_ASSISTER_DOMINATION =	2	// assister is dominating victim
const TF_DEATH_REVENGE =				4	// killer got revenge on victim
const TF_DEATH_ASSISTER_REVENGE =		8	// assister got revenge on victim
const TF_DEATH_FIRST_BLOOD =			16  // death triggered a first blood
const TF_DEATH_FEIGN_DEATH =			32  // feign death
const TF_DEATH_INTERRUPTED =			64	// interrupted a player doing an important game event (like capping or carrying flag)
const TF_DEATH_GIBBED =					128	// player was gibbed
const TF_DEATH_PURGATORY =				256	// player died while in purgatory
const TF_DEATH_MINIBOSS = 				512	// player killed was a miniboss
const TF_DEATH_AUSTRALIUM =				1024	// player killed by a Australium Weapon

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

::clamp <- function (value, min, max)
{
    if (value < min)
        return min;
    if (value > max)
        return max;
    return value;
}

::DistToSqr <- function(a, b)
{
	local dx = abs(a.x - b.x)
	local dy = abs(a.y - b.y)
	local dz = abs(a.z - b.z)
	return (dx * dx) + (dy * dy) + (dz * dz)
}


::DotProduct <- function(a, b)
{
	return ( a.x*b.x + a.y*b.y + a.z*b.z );
}