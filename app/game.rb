require 'app/character.rb'
require 'app/level_factory.rb'
require 'app/player.rb'

class Game
  attr_gtk

  def tick
    render
    input
    calc
  end


  def render
    level.render(outputs)
    player.render(args)

    outputs.labels << { x: 30, y: 30.from_top, text: "damage: #{player.damage || 0}" }
    outputs.labels << { x: 30, y: 60.from_top, text: "angle: #{inputs.directional_angle || player.angle}" }
  end


  def input
    player.input(args, inputs)

    player.angle = inputs.directional_angle || player.angle
    if inputs.controller_one.key_down.a || inputs.keyboard.key_down.space
      player.attacked_at = state.tick_count
    end

    if inputs.keyboard.key_down.q
      $gtk.console.log 'hello'
    end
  end


  def calc
    calc_player
    calc_projectiles
    calc_enemies
    calc_spawn_locations
  end


  def calc_player
    player.calc(args)

    if player.attacked_at.elapsed_time > 5

      future_player = future_player_position inputs.left_right * 2, inputs.up_down * 2
      #future_player = player.merge player.future_position(inputs.left_right * 2, inputs.up_down * 2)

      future_player_collision = future_collision player, future_player, level.walls
      player.x = future_player_collision.x if !future_player_collision.dx_collision
      player.y = future_player_collision.y if !future_player_collision.dy_collision
    end
  end


  def calc_projectile_collisions entities
    entities.each do |e|
      e.damage ||= 0
      player.projectiles.each do |p|
        if !p.collided && (p.intersect_rect? e)
          p.collided = true
          e.damage  += 1
        end
      end
    end
  end


  def calc_projectiles
    player.projectiles.map! do |p|
      dx, dy = p.angle.vector 10
      p.merge(x: p.x + dx, y: p.y + dy)
    end

    calc_projectile_collisions level.walls + level.enemies + level.spawn_locations
    player.projectiles.reject! { |p| p.at.elapsed_time > 10000 }
    player.projectiles.reject! { |p| p.collided }
    level.enemies.reject! { |e| e.damage > e.hp }
    level.spawn_locations.reject! { |s| s.damage > s.hp }
  end


  def calc_enemies
    level.enemies.map! do |e|
      dx =  0
      dx =  1 if e.x < player.x
      dx = -1 if e.x > player.x
      dy =  0
      dy =  1 if e.y < player.y
      dy = -1 if e.y > player.y
      future_e           = future_entity_position dx, dy, e
      future_e_collision = future_collision e, future_e, level.enemies + level.walls
      e.next_x = e.x
      e.next_y = e.y
      e.next_x = future_e_collision.x if !future_e_collision.dx_collision
      e.next_y = future_e_collision.y if !future_e_collision.dy_collision
      e
    end

    level.enemies.map! do |e|
      e.x = e.next_x
      e.y = e.next_y
      e
    end

    level.enemies.each do |e|
      player.damage += 1 if e.intersect_rect? player
    end
  end


  def calc_spawn_locations
    level.spawn_locations.map! do |s|
      s.merge(countdown: s.countdown - 1)
    end
    level.spawn_locations
         .find_all { |s| s.countdown.neg? }
         .each do |s|
      s.countdown = s.rate
      s.merge(countdown: s.rate)
      new_enemy = create_enemy s
      if !(level.enemies.find { |e| e.intersect_rect? new_enemy })
        level.enemies << new_enemy
      end
    end
  end


  def create_enemy (spawn_location)
    to_cell(spawn_location.ordinal_x, spawn_location.ordinal_y).merge hp: 2
  end


  def player
    state.player ||= Player.new
  end


  def level
    state.level ||= LevelFactory.create_level_one_template
  end


  def future_collision (entity, future_entity, others)
    dx_collision = others.find { |o| o != entity && (o.intersect_rect? future_entity.dx) }
    dy_collision = others.find { |o| o != entity && (o.intersect_rect? future_entity.dy) }

    {
      dx_collision: dx_collision,
      x: future_entity.dx.x,
      dy_collision: dy_collision,
      y: future_entity.dy.y
    }
  end


  def future_entity_position (dx, dy, entity)
    {
      dx:   entity.merge(x: entity.x + dx),
      dy:   entity.merge(y: entity.y + dy),
      both: entity.merge(x: entity.x + dx, y: entity.y + dy)
    }
  end


  def future_player_position  dx, dy
    future_entity_position dx, dy, player
  end


  def to_cell ordinal_x, ordinal_y
    { x: ordinal_x * 16, y: ordinal_y * 16, w: 16, h: 16 }
  end
end
