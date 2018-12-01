/***
* Name: Flash Food
* Author: Loïc Pascal
* Description: Modelisation of a flash flood
* Tags: flood, flash flood, flooding
***/

model flood

global {
	int nbAdults <- 1 parameter: "Nombre adults: ";
	int nbRescuers <- 1 parameter: "Nombre rescuers: ";
	int nbChildrens <- 80;
	int grid_size <- 120;
	int maxSante <- 200 min:1;
	int levelOfWaterForHelp <- 3;
	int maxWaterLevel <- 10;
	file buildings_shapefile <- file("../includes/building.shp");
	
	init {
		create adult number: nbAdults;
		create rescuer number: nbRescuers;
		create building from: buildings_shapefile;
	}
	
	reflex halting when:empty(agents) {
    	do halt;
    }
}

/******************************
** PLACE
******************************/
grid place height: grid_size width: grid_size neighbors: 8 {
	int niveauEquipement;
	int waterLevel <- flip(0.2) ? rnd(maxWaterLevel) : 0 max:maxWaterLevel;
	rgb color <- rgb(0, (waterLevel = 0 ? 255 : 0), 25*waterLevel)
		  update:rgb(0, (waterLevel = 0 ? 255 : 0), 25*waterLevel);

	init {
		niveauEquipement <- 0;
		//if (grid_x = grid_size - 1) {
			//waterLevel <- rnd(10);
		//}
	}
	
	aspect placeAspect {
		draw geometry:square(1) color: color;
	}
	
	reflex flood {
		if (one_of(neighbors where (each.waterLevel = maxWaterLevel)) != nil) {
			waterLevel <- waterLevel + 1;
		}
	}
}

/******************************
** HUMAN
******************************/
species human skills:[moving] {
	int sante <- rnd(maxSante) min:0;
	place myPlace <- one_of(place);
	
	init {
		location <- {int(myPlace.location.x), int(myPlace.location.y)};
	}
}

/******************************
** CIVIL parent : HUMAN
******************************/
species civil parent:human {
	rescuer myRescuer <- nil;
	bool needHelp <- myPlace.waterLevel > levelOfWaterForHelp update:myPlace.waterLevel > levelOfWaterForHelp;
	
	init {
		if (needHelp) {
			myRescuer <- rescuer where (each.civilToRescue = nil) closest_to(self);
		}
	}
	
	reflex survive {
		//sante <- sante - myPlace.waterLevel;
	}
	
	reflex die when: sante <= 0 {
		write "A civil died";
		myRescuer.civilToRescue <- nil;
		do die;
	}
	
	reflex ask_help when:(needHelp and myRescuer=nil) {
		myRescuer <- rescuer closest_to(self);
		if (myRescuer.civilToRescue = nil) {
			ask myRescuer {
				do saveLife(myself);
			}
		}
	}
}

/******************************
** ADULT parent : CIVIL
******************************/
species adult parent:civil {
	
	aspect adultAspect {
		draw geometry:square(2) color:#orange;
	}
	
	reflex move {
		if (myRescuer != nil) {
			float distanceTo_myRescuer <- sqrt((myRescuer.location.x - self.location.x)^2+(myRescuer.location.y - self.location.y)^2);
			write "distanceTo_myRescuer : " + distanceTo_myRescuer;
			if (myPlace.waterLevel > 0 and distanceTo_myRescuer > 10) {			// and flip(sante/maxSante)
				place nextPlace <- place at_distance(10) where (each.waterLevel < myPlace.waterLevel) closest_to(self) ;
				do goto target:nextPlace;
			}
		}
	}
}

/******************************
** CHILDREN parent : CIVIL
******************************/
species children parent:civil {
	
	aspect childrenAspect {
		draw geometry:square(1) color: rgb(150, 150, 150);
	}
}

/******************************
** RESCUER parent : HUMAN
******************************/
species rescuer parent:human {
	civil civilToRescue <- nil;
	
	init {
		speed <- 0.0;
		heading <- 360.0;
	}
	
	aspect rescuerAspect {
		draw geometry:circle(1) color: rgb(231, 76, 60);
	}
	
	reflex die when: sante <= 0 {
		write "A rescuer died";
		civilToRescue.myRescuer <- nil;
		do die;
	}
	
	reflex rescue when:civilToRescue!=nil {
		do saveLife(civilToRescue);
	}
	
	action saveLife(civil c) {
		civilToRescue <- c;
		myPlace <- place({location.x, location.y});
		speed <- (0.2 * (maxWaterLevel - myPlace.waterLevel)) + 1.0; // Vitesse proportionnelle au niveau de l'eau (de 1.0 à 3.0)
		do goto target:civilToRescue;
	}
}

/******************************
** CAR
******************************/
species building {
	float height <- 10 # m + rnd(10) # m;
	aspect default
	{
		draw shape color:# gray depth: height;
	}
}

experiment suddenFlood type:gui {
	output{
		display suddenFloodDisplay {
			species place aspect: placeAspect;
			species adult aspect: adultAspect;
			species children aspect: childrenAspect;
			species rescuer aspect: rescuerAspect;
			species building aspect: default;
		}
	}
}

