CREATE TABLE IF NOT EXISTS `management_funds` (
`id` INT(11) NOT NULL AUTO_INCREMENT,
`job_name` VARCHAR(50) NOT NULL,
`amount`  INT(100) NOT NULL,
`type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
PRIMARY KEY (`id`),
UNIQUE KEY `job_name` (`job_name`),
KEY `type` (`type`)
);

-- Seed rows for the jobs and gangs defined in w_core/shared/jobs.lua and gangs.lua.
-- Accounts for other jobs/gangs are created on first deposit (ON DUPLICATE KEY UPDATE).
INSERT INTO `management_funds` (`job_name`, `amount`, `type`) VALUES
('police', 0, 'boss'),
('ambulance', 0, 'boss'),
('realestate', 0, 'boss'),
('railroad', 0, 'boss'),
('judge', 0, 'boss'),
('lawyer', 0, 'boss'),
('example', 0, 'gang');
