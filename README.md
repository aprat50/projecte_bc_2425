## PROJECTE ASSET-LOAN
### PROJECTE BLOKCHAIN - GESTIÓ PRÉSTEC ACTIUS INSTITUT

#### **SMART CONTRACT** 
Conté la lógica per la gestió del préstec (prestar, retornar), així com l'enregistrament d'actius i possible modificació del seu estat.    

Les operacions estan controlades mitjançant dues Whitelist (carteres d'administradors i carteres de prestataris (alumnes, professors)) determinades accions només les poden fer els administradors.   

#### **CLIENT.SH** 
Conté la interficie CLI per interactuar amb el contracte.

Operacions exclusives de l'administrador:
- Registrar un actiu
- Actualitzar l'estat d'un actiu
- Gestionar les llistes blanques (administradors i resta d'usuaris)

Operacions obertes a tots els usuaris (sempre han d'existir a la llista blanca)
- Rebre un actiu en préstec
- Tornar un actiu prestat (només ho podrà fer el prestatari)
- Consultar actius (per codi d'actiu o per codi de cartera)

  
