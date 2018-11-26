/***
* Name: flood
* Author: loicp
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model flood

/* Insert your model definition here */

global {
	int nbAdults <- 80 parameter: "Nombre adults: ";
	int nbRescuers <- 30 parameter: "Nombre rescuers: ";
	int nbChildrens <- 80;
	int grid_size <- 90;
	int maxSante <- 200 min:1;
	int levelOfWaterForHelp <- 3;
	
	float step <- 1°h;
	
	init {
		create adult number: nbAdults;
		create rescuer number: nbRescuers;
	}
}

/******************************
** PLACE
******************************/
grid place height: grid_size width: grid_size neighbors: 8 {
	int niveauEquipement;
	int waterLevel max:10;
	rgb color <- rgb(0, (waterLevel = 0 ? 255 : 0), 25*waterLevel)
		update:rgb(0, (waterLevel = 0 ? 255 : 0), 25*waterLevel);

	init {
		niveauEquipement <- 0;
		waterLevel <- flip(0.2) ? rnd(10) : 0;
		color <- rgb(0, (waterLevel = 0 ? 255 : 0), 25*waterLevel);
	}
	
	aspect placeAspect {
		draw square(3) color: color;
	}
	
	reflex flood {
		if (one_of(neighbors where (each.waterLevel = 10)) != nil) {
			waterLevel <- waterLevel + 1;
		}
	}
}

/******************************
** HUMAN
******************************/
species human {
	int sante min:0;
	place myPlace;
	
	init {
		sante <- rnd(maxSante);
		myPlace <- one_of(place);
		location <- {int(myPlace.location.x), int(myPlace.location.y)};
	}
	
	reflex survive {
		sante <- sante - myPlace.waterLevel;
	}
}

/******************************
** CIVIL
******************************/
species civil parent:human {
	rescuer myRescuer <- nil;
	bool needHelp <- myPlace.waterLevel > levelOfWaterForHelp update:myPlace.waterLevel > levelOfWaterForHelp;
	
	init {
		if (needHelp) {
			myRescuer <- rescuer where (each.civilToRescue = nil) closest_to(self);
		}
	}
	
	reflex die when: sante <= 0 {
		myRescuer.civilToRescue <- nil;
		do die;
	}
	
	reflex ask_help when:(needHelp) {
		myRescuer <- rescuer closest_to(self);
		if (myRescuer.civilToRescue = nil) {
			ask myRescuer {
				do pleaseSaveLife(myself);
			}
		}
	}
}

/******************************
** ADULT
******************************/
species adult parent:civil {
	
	aspect adultAspect {
		draw circle(1) color: rgb(100, 100, 100);
	}
	
	reflex move {
		if (myRescuer != nil) {
			float distance <- sqrt((myRescuer.location.x - self.location.x)^2+(myRescuer.location.y - self.location.y)^2);
			
			if (distance > 10) {
				place nextPlace;
				
				if ((myPlace.waterLevel > 0) and flip(sante/maxSante)) {
					nextPlace <- one_of(myPlace.neighbors);
					myPlace <- nextPlace;
					location <- myPlace.location;
				}
			}
		}
	}
}

/******************************
** CHILDREN
******************************/
species children parent:civil {
	
	aspect childrenAspect {
		draw circle(1) color: rgb(150, 150, 150);
	}
	
	reflex move {
	}
}

/******************************
** RESCUER
******************************/
species rescuer parent:human {
	civil civilToRescue <- nil;
	
	aspect rescuerAspect {
		draw square(2) color: rgb(231, 76, 60);
	}
	
	reflex die when: sante <= 0 {
		do die;
	}
	
	reflex rescue {
		do saveLife;
	}
	
	action pleaseSaveLife(civil c) {
		civilToRescue <- c;
		do saveLife;
	}
	
	action saveLife {
		if (civilToRescue != nil) {
			int newLocationX <- int(location.x);
			if (int(civilToRescue.location.x) > int(self.location.x)) {
				newLocationX <- int(location.x) + 1;
			} else if(int(civilToRescue.location.x) < int(self.location.x)) {
				newLocationX <- int(location.x) - 1;
			}
			
			int newLocationY <- int(location.y);
			if (int(civilToRescue.location.y) > int(self.location.y)) {
				newLocationY <- int(location.y) + 1;
			} else if(int(civilToRescue.location.y) < int(self.location.y)) {
				newLocationY <- int(location.y) - 1;
			}
			
			location <- {newLocationX, newLocationY};
			//draw polyline([self.location,c.location]) color:#white width:5;
		}
	}
}

/******************************
** CAR
******************************/
species car {
	
	init {
		shape <- rectangle(2,3);
	}
}

experiment suddenFlood type:gui {
	output{
		display affichage {
			species place aspect: placeAspect;
			species adult aspect: adultAspect;
			species children aspect: childrenAspect;
			species rescuer aspect: rescuerAspect;
		}
	}
}

