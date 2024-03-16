const express = require('express');
const http = require('http');
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
const mongoose = require('mongoose');
var io = require("socket.io")(server);
const Room = require('./models/room');
const getWord = require('./api/getWord');

//middlewares
app.use(express.json());

//connect to database
const DB = 'mongodb+srv://sarthaksethi5:ugo8me@cluster0.0dg3gh7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0';

mongoose.connect(DB).then(() => {
}).catch((e) => { console.log(e) });

io.on("connection", (socket) => {
    //CREATE GAME
    socket.on('create-game', async ({ nickname, name, occupancy, maxrounds }) => {
        try {
            console.log({ nickname, name, occupancy, maxrounds });
            const existingRoom = await Room.findOne({ name });
            if (existingRoom) {
                socket.emit('notCorrectGame', 'Room with that name already exists!');
                return;
            }
            let room = new Room();
            const word = getWord();
            room.word = word;
            room.name = name;
            room.occupancy = occupancy;
            room.maxrounds = maxrounds;
            console.log(room);

            let player = {
                socketId: socket.id,
                nickname: nickname,
                isPartyLeader: true,
            }

            room.players.push(player);
            room = await room.save();
            socket.join(name);
            io.to(name).emit('updateRoom', room);
        } catch (err) {
            console.log(err);
        }
    });

    //JOIN GAME
    socket.on('join-game', async ({ nickname, name }) => {
        try {
            let room = await Room.findOne({ name });
            if (!room) {
                socket.emit('notCorrectGame', 'Please enter a valid room name');
                return;
            }

            if (room.isJoin) {
                let player = {
                    socketId: socket.id,
                    nickname: nickname
                }
                room.players.push(player);
                socket.join(name);

                if (room.players.length === room.occupancy) {
                    room.isJoin = false;
                }
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                io.to(name).emit('updateRoom', room);
            }
            else {
                socket.emit('notCorrectGame', 'The game is in progress!! Please try again later!!');
            }
        } catch (error) {
            console.log(error);
        }
    });

    socket.on('updateScore',async(name)=>{
        try {
            const room = await Room.findOne({name});
            io.to(name).emit("updateScore", room);
        } catch (error) {
            console.log(error);
        }
    });

    //white board socket
    socket.on('paint', ({ details, roomName }) => {
        io.to(roomName).emit('points', { details: details });
    });

    //color socket
    socket.on('color-change', ({ color, roomName }) => {
        io.to(roomName).emit('color-change', color);
    });

    //stroke-width
    socket.on('stroke-width', ({ value, roomName }) => {
        io.to(roomName).emit('stroke-width', value);
    });

    //clear screen
    socket.on('clear-screen', (roomName) => {
        io.to(roomName).emit('clear-screen', '');
    });

    //message sending and receiving
    socket.on('msg', async (data) => {
        try {
            if (data.msg == data.word) {
                let room = Room.find({ name: data.roomName });
                let userPlayer = room[0].players.filter(
                    (player) => { player.nickname == data.username }
                );

                if (data.timeTaken !== 0) {
                    userPlayer[0].points += Math.round((200 / data.timeTaken) * 10);
                }
                room = await room[0].save();
                io.to(data.roomName).emit('msg', {
                    username: data.username,
                    msg: "Guessed it!",
                    guessedUserCtr: data.guessedUserCtr + 1,
                })
                socket.emit('closeInput',"");
            } else {

                io.to(data.roomName).emit('msg',
                    {
                        username: data.username,
                        msg: data.msg,
                        guessedUserCtr: data.guessedUserCtr,
                    });
            }
        } catch (error) {
            console.log(error.toString());
        }
    });

    socket.on('change-turn', async (name) => {
        try {
            let room = await Room.findOne({ name });
            let idx = room.turnIndex;
            if (idx + 1 == room.players.length) {
                room.currentround += 1;
            }
            if (room.currentround <= room.max) {
                const word = getWord();
                room.word = word;
                room.turnIndex = (idx + 1) % room.players.length;
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                io.to(name).emit('change-turn', room);
            }
            else{
                io.to(name).emit('show-leaderboard',room.players);
            }
        } catch (error) {
            console.log(error.toString());
        }
    })

    socket.on('disconnect',async()=>{
        try {
            let room = Room.findOne({'players.socketId':socket.id});
            for( let i =0 ;i<room.player.length;i++){
                if(room.players[i].socketId===socket.id){
                    room.players.splice(i,1);
                    break;
                }
            }
            room = await room.save();
            if(room.players.length===1){
                socket.broadcast.to(room.name).emit('show-leaderboard',room.players);
            }
            else{
                socket.broadcast.to(room.name).emit('user-disconnected',room);
            }
        } catch (err) {
            
        }
    });
});

server.listen(port, "0.0.0.0", () => { console.log("Server started running on port " + port) });