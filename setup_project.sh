#!/bin/bash

# Установка Node.js и npm (если еще не установлены)
if ! command -v node &> /dev/null
then
    echo "Node.js не установлен. Устанавливаем Node.js и npm..."
    sudo apt-get update
    sudo apt-get install -y curl
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Установка конкретной версии npm
echo "Устанавливаем npm версии 10.8.2..."
npm install -g npm@10.8.2

# Установка NestJS CLI (если еще не установлен)
if ! command -v nest &> /dev/null
then
    echo "NestJS CLI не установлен. Устанавливаем NestJS CLI..."
    npm install -g @nestjs/cli
fi

# Создание нового проекта
echo "Создаем новый проект NestJS..."
nest new trello-clone --skip-git --package-manager npm

cd trello-clone || exit

# Установка зависимостей
echo "Устанавливаем зависимости проекта..."
npm install @nestjs/jwt @nestjs/passport passport passport-jwt bcryptjs @nestjs/typeorm typeorm mysql2 class-validator class-transformer @nestjs/swagger swagger-ui-express

# Создание файлов и директорий
echo "Создаем файлы и директории..."

mkdir -p src/auth src/users src/columns src/cards src/comments src/users/dto

# auth/auth.module.ts
cat > src/auth/auth.module.ts <<EOL
import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtModule } from '@nestjs/jwt';
import { JwtStrategy } from './jwt.strategy';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    JwtModule.register({
      secret: 'yourSecretKeyHere', // Change this to a secure key
      signOptions: { expiresIn: '60m' },
    }),
    UsersModule,
  ],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController],
})
export class AuthModule {}
EOL

# auth/auth.service.ts
cat > src/auth/auth.service.ts <<EOL
import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.usersService.findOneByEmail(email);
    if (user && await bcrypt.compare(password, user.password)) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: any) {
    const payload = { email: user.email };
    return {
      access_token: this.jwtService.sign(payload),
    };
  }
}
EOL

# auth/auth.controller.ts
cat > src/auth/auth.controller.ts <<EOL
import { Controller, Post, Body } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() body: { email: string; password: string }) {
    return this.authService.login(body);
  }
}
EOL

# auth/jwt.strategy.ts
cat > src/auth/jwt.strategy.ts <<EOL
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, ExtractJwt } from 'passport-jwt';
import { UsersService } from '../users/users.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private usersService: UsersService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: 'yourSecretKeyHere', // Change this to a secure key
    });
  }

  async validate(payload: any) {
    return await this.usersService.findOneByEmail(payload.email);
  }
}
EOL

# users/users.module.ts
cat > src/users/users.module.ts <<EOL
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
EOL

# users/user.entity.ts
cat > src/users/user.entity.ts <<EOL
import { Column as TypeOrmColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @TypeOrmColumn({ unique: true })
  email: string;

  @TypeOrmColumn()
  password: string;
}
EOL

# users/users.service.ts
cat > src/users/users.service.ts <<EOL
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  createUser(email: string, password: string): Promise<User> {
    const user = this.usersRepository.create({ email, password });
    return this.usersRepository.save(user);
  }

  findOne(id: number): Promise<User> {
    return this.usersRepository.findOneBy({ id });
  }

  findAll(): Promise<User[]> {
    return this.usersRepository.find();
  }

  async remove(id: number): Promise<void> {
    await this.usersRepository.delete(id);
  }
  
  async findOneByEmail(email: string): Promise<User> {
    return this.usersRepository.findOneBy({ email });
  }
}
EOL

# users/users.controller.ts
cat > src/users/users.controller.ts <<EOL
import { Controller, Post, Body, Get, Param, Delete } from '@nestjs/common';
import { UsersService } from './users.service';
import { User } from './user.entity';
import { CreateUserDto } from './dto/create-user.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  create(@Body() createUserDto: CreateUserDto): Promise<User> {
    return this.usersService.createUser(createUserDto.email, createUserDto.password);
  }

  @Get(':id')
  findOne(@Param('id') id: number): Promise<User> {
    return this.usersService.findOne(id);
  }

  @Get()
  findAll(): Promise<User[]> {
    return this.usersService.findAll();
  }

  @Delete(':id')
  remove(@Param('id') id: number): Promise<void> {
    return this.usersService.remove(id);
  }
}
EOL

# users/dto/create-user.dto.ts
cat > src/users/dto/create-user.dto.ts <<EOL
import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'password123' })
  @IsString()
  @MinLength(6)
  password: string;
}
EOL

# columns/column.entity.ts
cat > src/columns/column.entity.ts <<EOL
import { Entity, PrimaryGeneratedColumn, Column as TypeOrmColumn } from 'typeorm';

@Entity()
export class ColumnEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @TypeOrmColumn()
  name: string;

  @TypeOrmColumn()
  position: number;
}
EOL

# cards/card.entity.ts
cat > src/cards/card.entity.ts <<EOL
import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class Card {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @Column()
  description: string;

  @Column()
  columnId: number;
}
EOL

# comments/comment.entity.ts
cat > src/comments/comment.entity.ts <<EOL
import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class Comment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  text: string;

  @Column()
  cardId: number;
}
EOL

# app.module.ts
cat > src/app.module.ts <<EOL
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ColumnEntity } from './columns/column.entity';
import { Card } from './cards/card.entity';
import { Comment } from './comments/comment.entity';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'mysql',
      host: 'localhost',  # Замените на IP или хост вашего MySQL сервера, если необходимо
      port: 3306,
      username: 'root',
      password: 'password', # Замените на ваш пароль MySQL
      database: 'trello_clone',
      entities: [ColumnEntity, Card, Comment],
      synchronize: true, # Убедитесь, что это значение установлено в true только в процессе разработки
    }),
    UsersModule,
    AuthModule,
  ],
})
export class AppModule {}
EOL
