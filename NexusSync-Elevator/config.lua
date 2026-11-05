Config = {}
Config.Framework = 'auto' -- auto, qbox, qbcore, esx, standalone
Config.CreatorCommand = 'elevatorcreator'
Config.AdminAce = 'ns_elevator.admin'
Config.InteractDistance = 2.5
Config.TargetRadius = 0.25 -- Includes the wall collision behind the panel
Config.RenderDistance = 18.0
Config.Target = 'auto' -- auto, ox_target, qb-target
Config.TravelDuration = 1500 -- Visible delay after closing the menu
Config.UseScreenFade = false -- Default for elevators without an override: true = black screen, false = visible teleport
Config.FadeDuration = 200 -- Fade out/in duration in milliseconds
Config.CollisionTimeout = 5000
Config.MaxElevators = 100
Config.MaxFloors = 40
Config.DataFile = 'data/elevators.json'
