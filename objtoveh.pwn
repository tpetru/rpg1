/*
	Dynamic attach system for Vehicles.
	Created by Siralos
*/

#define FILTERSCRIPT
#include <a_samp>
#include <YSI\y_commands>
#include <YSI\y_master>
#include <sscanf2>

#define MAX_OBJ_PER_VEHICLE 20

new AttachingObjects[MAX_PLAYERS];
new AttachedObjects[MAX_VEHICLES][MAX_OBJ_PER_VEHICLE];
new strout[128];

public OnScriptInit()
{
	printf("Attach object to Vehicle by Siralos");
	return 1;
}

public OnScriptExit()
{
	//Clear all objects created
	for(new i=0; i<MAX_VEHICLES; i++)
	{
		if(GetVehicleModel(i) > 0)
		{
			for(new j=0; j<MAX_OBJ_PER_VEHICLE; j++)
			{
				if(IsValidObject(AttachedObjects[i][j]))
				{
					DestroyObject(AttachedObjects[i][j]);
				}
			}
		}
	}
	return 1;
}

YCMD:mycarid(playerid, params[], help)
{
	#pragma unused help
	#pragma unused params
	new car = GetPlayerVehicleID(playerid);
	if(car == 0) return SendClientMessage(playerid, 0xfce80cFF, "You are not in a car");
	format(strout, sizeof(strout), "Car ID: %d", car);
	return SendClientMessage(playerid, 0xfce80cFF, strout);
}

YCMD:deleteobject(playerid, params[], help)
{
	#pragma unused help
	new arrayid, car;
	if(sscanf(params, "ii", arrayid, car))
	{
		SendClientMessage(playerid, 0xfce80cFF, "Use: /deleteobject [arrayid] [SAMP Car ID]");
		return 1;
	}
	if(0 <= arrayid < 20)
	{
		if(0 < car < MAX_VEHICLES)
		{
			if(!IsValidObject(AttachedObjects[car][arrayid]))
			{
				SendClientMessage(playerid, 0xfce80cFF, "No object found at position");
				return 1;
			}
			DestroyObject(AttachedObjects[car][arrayid]);
			SendClientMessage(playerid, 0xfce80cFF, "Object removed");
			return 1;
		}
		else
		{
			SendClientMessage(playerid, 0xfce80cFF, "Invalid vehicle");
		}
	}
	else
	{
		SendClientMessage(playerid, 0xfce80cFF, "No object found at position");
	}
	return 1;
}

YCMD:attachobject(playerid, params[], help)
{
	#pragma unused help
	new objectmodel, car;
	if(sscanf(params, "ii", objectmodel, car))
	{
		SendClientMessage(playerid, 0xfce80cFF, "Use: /attachobject [object model] [SAMP Car ID]");
		return 1;
	}
	if(0 < car < MAX_VEHICLES)
	{
		new Float:px, Float:py, Float:pz;
		GetPlayerPos(playerid, px, py, pz);
		AttachingObjects[playerid] = CreateObject(objectmodel, px, py, pz, 0.0, 0.0, 0.0);
		SendClientMessage(playerid, 0xfce80cFF, "Object created. Editing...");
		EditObject(playerid, AttachingObjects[playerid]);
		SetPVarInt(playerid, "AttachingTo", car);
	}
	else
	{
		SendClientMessage(playerid, 0xfce80cFF, "Invalid vehicle");
	}
	return 1;
}

public OnPlayerEditObject(playerid, playerobject, objectid, response, Float:fX, Float:fY, Float:fZ, Float:fRotX, Float:fRotY, Float:fRotZ)
{
	if(!IsValidObject(objectid)) return 0;
	MoveObject(objectid, fX, fY, fZ, 10.0, fRotX, fRotY, fRotZ);

	new car = GetPVarInt(playerid, "AttachingTo");
	if(car != 0)
	{
		if(response == EDIT_RESPONSE_FINAL)
		{
			SendClientMessage(playerid, 0xfce80cFF, "Finished Edition.");
			new carslot = FindFreeObjectSlotInCar(car);
			if(carslot == -1)
			{
				SendClientMessage(playerid, 0xfce80cFF, "No more objects can be added to the car.");
				DestroyObject(AttachingObjects[playerid]);
				DeletePVar(playerid, "AttachingTo");
				return 1;
			}
			new Float:ofx, Float:ofy, Float:ofz, Float:ofaz;
			new Float:finalx, Float:finaly;
			new Float:px, Float:py, Float:pz, Float:roz;
			GetVehiclePos(car, px, py, pz);
			GetVehicleZAngle(car, roz);
			ofx = fX-px;
			ofy = fY-py;
			ofz = fZ-pz;
			ofaz = fRotZ-roz;
			finalx = ofx*floatcos(roz, degrees)+ofy*floatsin(roz, degrees);
			finaly = -ofx*floatsin(roz, degrees)+ofy*floatcos(roz, degrees);
			AttachObjectToVehicle(AttachingObjects[playerid], car, finalx, finaly, ofz, fRotX, fRotY, ofaz);
			AttachedObjects[car][carslot] = AttachingObjects[playerid];
			format(strout, sizeof(strout), "Created in array slot %d of car %d", carslot, car);
			SendClientMessage(playerid, 0xfce80cFF, strout);
			DeletePVar(playerid, "AttachingTo");
			return 1;
		}
		if(response == EDIT_RESPONSE_CANCEL)
		{
			DestroyObject(AttachingObjects[playerid]);
			DeletePVar(playerid, "AttachingTo");
			return 1;
		}
	}
	return 0;
}

stock FindFreeObjectSlotInCar(vehid)
{
	for(new i=0; i<MAX_OBJ_PER_VEHICLE; i++)
	{
		if(!IsValidObject(AttachedObjects[vehid][i])) return i;
	}
	return -1;
}
