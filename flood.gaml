/***
* Name: Flash Food
* Author: Loïc Pascal
* Description: Modelisation of a flash flood
* Tags: flood, flash flood, flooding
***/

model flood

global {
	file roads_shapefile <- file("includes/road.shp");
	graph road_network;
	file buildings_shapefile <- file("includes/building.shp");
	
	geometry shape <- envelope(roads_shapefile);
	int nbAdults <- 15;
	int nbCars <- 10;
	int nbChildrens <- 10;
	int nbOldPersons <- 10;
	int nbRescuerInCar <- 10;
	int nbRescuerInHelicopter <- 6;
	
	int grid_size <- 90;
	int maxSante <- 200;
	int levelOfWaterForHelp <- 2;
	int maxWaterLevel <- 200;
	int waterLevelToFloodNeighbors <- 40;
	int maxEquipmentLevel <- 200;
	int floodIntensity <- 10;
	
	int nbDeadCivil <- 0;
	
	building safeBuilding;
	
	init {
		create building from: buildings_shapefile {
			ask place overlapping self {
				isBuilding <- true;
			}
		}
		create road from: roads_shapefile;
		create adult number: nbAdults;
		create children number: nbChildrens;
		create oldPerson number: nbOldPersons;
		create civilInCar number: nbCars;
		create rescuerInCar number: nbRescuerInCar;
		create rescuerInHelicopter number: nbRescuerInHelicopter;
		road_network <- as_edge_graph(road);
		safeBuilding <- one_of(building where(each.name = "building133"));
	}
	
	reflex halting when:empty(agents) {
    	do halt;
    }
}

/******************************
** PLACE
******************************/
grid place height: grid_size width: grid_size neighbors: 8 {
	int equipmentLevel min:0 max:maxEquipmentLevel;
	int waterLevel min:0 max:maxWaterLevel;
	bool isBuilding <- false;
	rgb color <- rgb(waterLevel > 0 ? 0 : 255, waterLevel > 0 ? 0 : 255, waterLevel > 0 ? int(1.275*waterLevel) : 255)
		  update:rgb(waterLevel > 0 ? 0 : 255, waterLevel > 0 ? 0 : 255, waterLevel > 0 ? int(1.275*waterLevel) : 255);

	init {
		equipmentLevel <- rnd(maxEquipmentLevel);
		
		if (grid_x = grid_size - 1) {
			waterLevel <- rnd(floodIntensity*10 - equipmentLevel);
		}
	}
	
	aspect placeAspect {
		draw geometry:square(12) color: color;
	}
	
	reflex flood {
		place floodedNeighbor <- one_of(neighbors where (each.waterLevel >= waterLevelToFloodNeighbors));
		if (floodedNeighbor != nil and flip(0.2)) {
			waterLevel <- waterLevel + int(floodIntensity) + int(floodedNeighbor.waterLevel/3) - equipmentLevel;
		}
	}
}

/******************************
** BUILDING
******************************/
species building {
	aspect default {
		draw shape color:#slategrey;
	}
}

/******************************
** ROAD
******************************/
species road
{
	geometry display_shape <- shape + 2.0;
	aspect default {
		draw display_shape color:#grey;
	}
}

/******************************
** HUMAN
******************************/
species human skills:[moving] {
	
	place myPlace <- nil;
	int sante min:0 max:200;
	bool isGoingToSafeBuilding <- false;
	
	reflex updatePlace {
		myPlace <- place({location.x, location.y});
	}
	
	/**
	 * The human go to the safe building by road
	 */
	action goToSafeBuildingInCar {
		isGoingToSafeBuilding <- true;
		speed <- (maxWaterLevel - myPlace.waterLevel)/2 + 10.0 # km / # h;
		do goto target:safeBuilding on:road_network recompute_path:false;
	}
	
	/**
	 * The human go to the safe building by all
	 */
	action goToSafeBuildingInHelicopter {
		isGoingToSafeBuilding <- true;
		speed <- (maxWaterLevel - myPlace.waterLevel)/10 + 10.0 # km / # h;
		do goto target:safeBuilding recompute_path:false;
	}
}

/******************************
** CIVIL parent : HUMAN
******************************/
species civil parent:human {
	
	rescuer myRescuer <- nil;
	bool isInSafePlace <- false;
	
	reflex survive when:(myPlace.waterLevel >= levelOfWaterForHelp and !isGoingToSafeBuilding) {
		sante <- sante - int(myPlace.waterLevel/10);
	}
	
	reflex die when: sante <= 0 {
		write "A civil died";
		myRescuer.civilToRescue <- nil;
		nbDeadCivil <- nbDeadCivil + 1;
		do die;
	}
	
	reflex ask_help when:(myPlace.waterLevel >= levelOfWaterForHelp and myRescuer = nil) {
		write "Civil ask Help !";
		myRescuer <- one_of((flip(0.5) ? rescuerInCar : rescuerInHelicopter) where (each.civilToRescue = nil) closest_to(self));
		if (myRescuer!= nil and myRescuer.civilToRescue = nil) {
			ask myRescuer {
				do saveLife(myself);
			}
		}
	}
}

/******************************
** CIVIL PEDESTRIAN parent : HUMAN
******************************/
species civilPedestrian parent:civil {
	
	init {
		if (flip(0.5)) {
			road myRoad <- one_of(road);
			location <- any_location_in(myRoad);
		} 
		else {
			building myBuilding <- one_of(building where(each.name != "building108" and each.name != "building122" and each.name != "building133"));
			location <- any_location_in(myBuilding);
		}
		myPlace <- place({location.x, location.y});
		speed <- 10.0 # km / # h;
	}
	
	reflex updateSpeed {
		speed <- 15.0 - (myPlace.waterLevel / 20) # km / # h;
	}
}

/******************************
** ADULT parent : CIVIL
******************************/
species adult parent:civilPedestrian {
	
	aspect adultAspect {
		draw square(8) color:#orange;
	}
	
	init {
		 sante <- 150 + rnd(int(0.25*maxSante));
	}
	
	reflex move when:(!isInSafePlace and ((myRescuer = nil) or ((myRescuer != nil) and (myPlace.waterLevel > 0) and (self distance_to myRescuer > 50)))) {
		place safePlace <- place where (each.waterLevel < myPlace.waterLevel) closest_to(self);
		do goto target:safePlace on:(place where not each.isBuilding);
	}
}

/******************************
** OLD PERSON parent : CIVIL
******************************/
species oldPerson parent:civilPedestrian {
	
	aspect oldPersonAspect {
		draw square(8) color:#springgreen;
	}
	
	init {
		 sante <- 100 + rnd(int(0.5*maxSante));
	}
}

/******************************
** CHILDREN parent : CIVIL
******************************/
species children parent:civilPedestrian {
	
	aspect childrenAspect {
		draw geometry:square(8) color: #magenta;
	}
	
	init {
		 sante <- 50 + rnd(int(0.75*maxSante));
	}
}

/******************************
** CAR parent : HUMAN
******************************/
species civilInCar parent:civil {
	
	aspect civilInCarAspect {
		draw rectangle(8, 14) + triangle(6) color: #black rotate: heading + 90;
	}
	
	init {
		location <- any_location_in(one_of(road));
		myPlace <- place({location.x, location.y});
		sante <- 150 + rnd(int(0.25*maxSante));
	}
}

/******************************
** RESCUER parent : HUMAN
******************************/
species rescuer parent:human {
	civil civilToRescue <- nil;
	
	init {
		sante <- 180 + rnd(int(0.1*maxSante));
		building myBuilding <- one_of(building where(each.name = "building108" or each.name = "building122"));
		location <- any_location_in(myBuilding);
		myPlace <- place({location.x, location.y});
		heading <- 360.0;
	}
	
	reflex die when: sante <= 0 {
		civilToRescue.myRescuer <- nil;
		do die;
	}
	
	reflex finishRescue when:self distance_to safeBuilding < 5 {
		civilToRescue.myRescuer <- nil;
		civilToRescue.isInSafePlace <- true;
		civilToRescue <- nil;
	}
	
	reflex rescue when: (civilToRescue != nil) {
		do saveLife(civilToRescue);
	}
	
	action saveLife(civil c) {
		if (civilToRescue = nil) {
			civilToRescue <- c;
		}
		
		// The rescuer arrived at the victim's place
		if ((self distance_to civilToRescue) < 5) {
			do bringCivilToSafePlace;
		} else {
			if (self is rescuerInCar) {
				do goto target:civilToRescue on:road_network recompute_path:false;
			} else {
			do goto target:civilToRescue recompute_path:false;
			}
		}
	}
	
	action bringCivilToSafePlace {
		do goToSafeBuilding;
	}
	
	action goToSafeBuilding virtual:true;
}

/******************************
** RESCUER PEDESTRIAN parent : RESCUER
******************************/
species rescuerInCar parent:rescuer {
	aspect rescuerInCarAspect {
		draw circle(8) color: rgb(231, 76, 60);
	}
	
	init {
		speed <- maxWaterLevel + 10.0 # km / # h;
	}
	
	reflex survive when:flip(0.01) {
		sante <- sante - int(myPlace.waterLevel/10);
	}
	
	reflex updateSpeed when:!isGoingToSafeBuilding {
		speed <- (maxWaterLevel - myPlace.waterLevel)/2 + 10.0 # km / # h; // Vitesse proportionnelle au niveau de l'eau
	}
	
	/**
	 * The rescuer go to the safe building by the road
	 */
	action goToSafeBuilding {
		do goToSafeBuildingInCar;
		ask civilToRescue {
			do goToSafeBuildingInCar;
		}
	}
}

/******************************
** RESCUER IN HELICOPTER parent : RESCUER
******************************/
species rescuerInHelicopter parent:rescuer {
	aspect rescuerInHelicopterAspect {
		draw rectangle(10, 20) color: rgb(231, 76, 60) rotate: heading + 90;
	}
	
	init {
		speed <- maxWaterLevel + 10.0 # km / # h;
	}
	
	/**
	 * The rescuer go to the safe building by the road
	 */
	action goToSafeBuilding {
		do goToSafeBuildingInHelicopter;
		ask civilToRescue {
			do goToSafeBuildingInHelicopter;
		}
	}
}

experiment suddenFlood type:gui {
	parameter "Max equipment level: " var:maxEquipmentLevel min:0 max:10 category:"Environment";
	parameter "Flood intensity: " var:floodIntensity min:0 max:20 category:"Environment";
	parameter "Number of adults: " var:nbAdults min:1 max:50 category:"Civils";
	parameter "Number of childrens: " var:nbChildrens min:1 max:50 category:"Civils";
	parameter "Number of old persons: " var:nbOldPersons min:1 max:50 category:"Civils";
	parameter "Number of cars: " var:nbCars min:1 max:50 category:"Cars";
	parameter "Number of pedestrian rescuers: " var:nbRescuerInCar min:1 max:50 category:"Rescuers";
	parameter "Number of rescuers in helicopter: " var:nbRescuerInHelicopter min:1 max:50 category:"Rescuers";
	
	output{
		display suddenFloodDisplay {
			species place aspect: placeAspect;
			species road transparency: 0.1;
			species building aspect: default transparency: 0.1;
			species adult aspect: adultAspect;
			species oldPerson aspect: oldPersonAspect;
			species children aspect: childrenAspect;
			species civilInCar aspect: civilInCarAspect;
			species rescuerInCar aspect: rescuerInCarAspect;
			species rescuerInHelicopter aspect: rescuerInHelicopterAspect;
		}
		
		display my_chart {
			chart "Number of civil alive" {
				data "civil alive" value: length(civil) color:#red;
				data "rescuer alive" value: length(rescuer) color:#red;
			}
		}
	}
}

